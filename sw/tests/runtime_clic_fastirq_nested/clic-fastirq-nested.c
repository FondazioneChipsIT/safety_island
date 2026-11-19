/* SPDX-License-Identifier: Apache-2.0 */

/* Test nested interrupts with the fast interrupt extension of the core
 * (SHADOW): every acknowledged interrupt moves sp down by 64 bytes and the
 * core writes in that frame, in the background, the 16 caller-saved registers.
 * It writes one frame at a time, and the logic that makes an interrupt wait
 * for the previous frame to be written is not effective. So an interrupt that
 * interrupts another one is safe only if it is acknowledged after the frame of
 * the first one is complete.
 *
 * irq_low:  interrupts 23 to 30, one for every distance, level 0x88
 * irq_high: interrupt 31, level 0xaa
 * 1. [thread]   Trigger irq_low (regs.S fills the caller-saved registers)
 * 2. [isr_low]  Raise irq_high and enable the interrupts, in the order and
 *               with the nops that depend on the interrupt (handler.S), so
 *               that irq_high is acknowledged at a different distance from
 *               irq_low
 * 3. [isr_high] Count
 * 4. [isr_low]  Check the frame of irq_high in memory
 * 5. [thread]   Check the registers and the frame of irq_low in memory
 *
 * The test prints, for each interrupt, whether the registers and the two
 * frames are right. It asserts only the largest distance: the ones in between
 * are the measure of how far apart the two interrupts have to be. Where they
 * are too close, the assertion a_shadow_controller_acces_while_saving of
 * cv32e40px_shadow_controller.sv is expected to fire in the simulation.
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "csr.h"
#include "io.h"
#include "pulp.h"

#include "clic.h"
#include "clicint.h"

#define assert(expression) \
    do { \
        if (!(expression)) { \
            printf("%s:%d: assert error\n", __FILE__, __LINE__); \
            exit(1); \
        } \
    } while (0)

#define MSHWINT_EN 0x1 /* save the registers on the interrupt entry */
#define IRQ_LOW_FIRST 23
#define IRQ_HIGH 31
#define NUM_LOW 8

void clic_setup_mtvec(void);
void clic_setup_mtvt(void);
void nested_run(void);

/* how the entries of irq_low of handler.S enable the interrupts and raise
 * irq_high, in the order of the interrupts */
static const struct {
    const char *what;
    uint32_t nops;
} low_entry[NUM_LOW] = {
    {"mie then raise", 0}, {"mie then raise", 1}, {"mie then raise", 2}, {"mie then raise", 3},
    {"mie then raise", 4}, {"raise then mie", 0}, {"mie then raise", 8}, {"mie then raise", 24},
};

/* shared with regs.S and handler.S */
volatile uint32_t high_count = 0;
volatile uint32_t nest_done = 0;
volatile uint32_t frameb_mask = 0;
volatile uint32_t high_trigger_addr = 0;
volatile uint32_t high_trigger_val = 0;
volatile uint32_t thread_regs_mask = 0;
volatile uint32_t thread_frame_mask = 0;

static uint32_t mclicbase;

/* called by __handle_high (handler.S) */
void isr_high(void) {
    high_count++;
}

/* called by __handle_exception (handler.S) */
void exception_isr(uint32_t cause, uint32_t epc, uint32_t tval) {
    printf("exception: mcause %08lx, mepc %08lx, mtval %08lx\n", cause, epc, tval);
    exit(1);
}

/* set or clear the pending bit via SW, even though the line is not asserted */
static void clic_set_ip(uint32_t id, uint32_t pending) {
    writew((pending << CLICINT_CLICINT_IP_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(id)) & ~(0x1 << CLICINT_CLICINT_IP_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(id));
}

/* set up and enable an edge triggered, hardware vectored interrupt */
static void clic_setup_irq(uint32_t id, uint32_t level) {
    /* enable selective hardware vectoring */
    writew((0x1 << CLICINT_CLICINT_ATTR_SHV_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(id)) & ~(0x1 << CLICINT_CLICINT_ATTR_SHV_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(id));

    /* set trigger type to edge-triggered */
    writew((0x1 << CLICINT_CLICINT_ATTR_TRIG_OFFSET) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(id)) &
                ~(CLICINT_CLICINT_ATTR_TRIG_MASK << CLICINT_CLICINT_ATTR_TRIG_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(id));

    /* set interrupt level and priority */
    writew((level << CLICINT_CLICINT_CTL_OFFSET) | (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(id)) &
                                                    ~(CLICINT_CLICINT_CTL_MASK << CLICINT_CLICINT_CTL_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(id));

    /* enable interrupt on clic */
    writew((0x1 << CLICINT_CLICINT_IE_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(id)) & ~(0X1 << CLICINT_CLICINT_IE_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(id));
}

/* run the two interrupts once, with the irq_low of the entry i as the one that
 * is triggered, and print what they left. Returns 1 if everything is right */
static uint32_t run(uint32_t i) {
    /* nothing can fire while the interrupts are set up again */
    csr_write(CSR_MINTTHRESH, 0xff);
    for (uint32_t j = 0; j < NUM_LOW; j++)
        clic_set_ip(IRQ_LOW_FIRST + j, 0);
    clic_set_ip(IRQ_HIGH, 0);
    high_count = 0;
    nest_done = 0;
    frameb_mask = 0xffffffff;
    thread_regs_mask = 0xffffffff;
    thread_frame_mask = 0xffffffff;

    /* irq_low is pending, but the threshold keeps it from firing: nested_run
     * lowers it once the registers are filled */
    clic_set_ip(IRQ_LOW_FIRST + i, 1);
    nested_run();

    uint32_t ok = high_count == 1 && nest_done == 1 && thread_regs_mask == 0 && thread_frame_mask == 0 &&
                  frameb_mask == 0;
    printf("%s, %lu nops: irq_high %lu, regs %08lx, frame low %08lx, frame high %08lx: %s\n", low_entry[i].what,
           low_entry[i].nops, high_count, thread_regs_mask, thread_frame_mask, frameb_mask, ok ? "ok" : "BAD");
    return ok;
}

int main(void) {

    /*
     * global address map
     * CLIC_START_ADDR      32'h1A20_0000
     * CLIC_CTRL_END_ADDR   32'h1A20_FFFF
     * See clic.h for register map
     */

    /* This tests works with edge triggered interrupts as default.
     * It uses clicintip[i] CLIC register to assert pending interrupt via
     * SW, even though the corresponding lines are not asserted in HW.
     */

    mclicbase = csr_read(CSR_MCLICBASE);
    printf("the readed CSR value is: %lx\n", mclicbase);

    uint32_t ok[NUM_LOW];
    uint32_t bad = 0;

    /* redirect vector table to our custom one */
    printf("set up vector table\n");
    clic_setup_mtvec();
    clic_setup_mtvt();

    /* the core saves the caller-saved registers on the interrupt entry */
    printf("enable fastirq\n");
    csr_write(CSR_MSHWINT, MSHWINT_EN);

    /* set number of bits for level encoding:
     * nlbits
     */
    printf("set nlbits\n");
    writew((0x4 << MCLIC_MCLICCFG_MNLBITS_OFFSET), mclicbase + MCLIC_MCLICCFG_REG_OFFSET);

    /* nothing is pending yet, so nothing fires */
    printf("set up irq_low (%d entries) and irq_high\n", NUM_LOW);
    for (uint32_t i = 0; i < NUM_LOW; i++)
        clic_setup_irq(IRQ_LOW_FIRST + i, 0x88);
    clic_setup_irq(IRQ_HIGH, 0xaa); /* 0xaa > 0x88 */

    /* the write that raises irq_high, done by the handler of irq_low */
    high_trigger_addr = mclicbase + CLICINT_CLICINT_REG_OFFSET(IRQ_HIGH);
    high_trigger_val = (0x1 << CLICINT_CLICINT_IP_BIT) | (readw(high_trigger_addr) & ~(0x1 << CLICINT_CLICINT_IP_BIT));

    for (uint32_t i = 0; i < NUM_LOW; i++) {
        ok[i] = run(i);
        bad += !ok[i];
    }

    printf("mshwint: %lx\n", csr_read(CSR_MSHWINT));
    printf("%lu of %d distances are not right\n", bad, NUM_LOW);

    /* the extension is on */
    assert(csr_read(CSR_MSHWINT) == MSHWINT_EN);
    /* two interrupts far enough from each other are saved and restored */
    assert(ok[NUM_LOW - 1]);

    return 0;
}
