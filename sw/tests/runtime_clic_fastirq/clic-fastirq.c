/* SPDX-License-Identifier: Apache-2.0 */

/* Test the fast interrupt extension of the core (SHADOW): on the interrupt
 * entry the core saves the 16 caller-saved registers (ra, t0-t2, a0-a7,
 * t3-t6) in a shadow register bank, moves sp down by 64 bytes and writes them
 * in the background in the frame it has opened, so that the handler does not
 * have to save them (handler.S). The extension is enabled with mshwint.
 *
 * The interrupted code (regs.S) fills the caller-saved registers with known
 * values and, after the interrupt, checks both the registers and the frame in
 * memory.
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
#define FRAME_SIZE 64  /* bytes: 16 registers */

void clic_setup_mtvec(void);
void clic_setup_mtvt(void);
void fastirq_run(uint32_t res[2], volatile uint32_t *irq_count);

/* what the handler saw */
static volatile uint32_t irq_count = 0;
static volatile uint32_t irq_sp = 0;

static inline uint32_t read_sp(void) {
    uint32_t sp;
    asm volatile("mv %0, sp" : "=r"(sp));
    return sp;
}

/* called by __handle_clic_int (handler.S) */
void clic_isr(void) {
    irq_sp = read_sp();
    irq_count++;
    /* raise the threshold above the level of interrupt 31 so that it cannot
     * fire again */
    csr_write(CSR_MINTTHRESH, 0xff);
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

    uint32_t mclicbase;
    mclicbase = csr_read(CSR_MCLICBASE);
    printf("the readed CSR value is: %lx\n", mclicbase);

    uint32_t thread_sp_before;
    uint32_t thread_sp_after;
    uint32_t res[2];

    /* redirect vector table to our custom one */
    printf("set up vector table\n");
    clic_setup_mtvec();
    clic_setup_mtvt();

    /* the core saves the caller-saved registers on the interrupt entry */
    printf("enable fastirq\n");
    csr_write(CSR_MSHWINT, MSHWINT_EN);

    /* enable selective hardware vectoring */
    printf("set shv\n");
    writew((0x1 << CLICINT_CLICINT_ATTR_SHV_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) & ~(0x1 << CLICINT_CLICINT_ATTR_SHV_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));

    /* set trigger type to edge-triggered */
    printf("set trigger type: edge-triggered\n");
    writew((0x1 << CLICINT_CLICINT_ATTR_TRIG_OFFSET) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) &
                ~(CLICINT_CLICINT_ATTR_TRIG_MASK << CLICINT_CLICINT_ATTR_TRIG_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));

    /* enable irq31 via SW by writing to clicintip31 */
    printf("enable irq31: set clicintip31 bit\n");
    writew((0x1 << CLICINT_CLICINT_IP_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) & ~(0x1 << CLICINT_CLICINT_IP_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));

    /* set number of bits for level encoding:
     * nlbits
     */
    printf("set nlbits\n");
    writew((0x4 << MCLIC_MCLICCFG_MNLBITS_OFFSET), mclicbase + MCLIC_MCLICCFG_REG_OFFSET);

    /* set interrupt level and priority for interrupt 31 */
    printf("set interrupt priority and level\n");
    writew((0xaa << CLICINT_CLICINT_CTL_OFFSET) | (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) &
                                                   ~(CLICINT_CLICINT_CTL_MASK << CLICINT_CLICINT_CTL_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));

    /* the threshold is above the level of the interrupt, so it cannot fire
     * yet: fastirq_run lowers it once the registers are filled */
    printf("set interrupt threshold \n");
    csr_write(CSR_MINTTHRESH, 0xff); /* 0xff > 0xaa */

    printf("enable interrupt 31\n");
    /* enable interrupt 31 on clic: it is already pending */
    writew((0x1 << CLICINT_CLICINT_IE_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) & ~(0X1 << CLICINT_CLICINT_IE_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));

    thread_sp_before = read_sp();

    printf("run the interrupt\n");
    fastirq_run(res, &irq_count);

    thread_sp_after = read_sp();

    printf("mshwint:               %lx\n", csr_read(CSR_MSHWINT));
    printf("thread sp before:      %08lx\n", thread_sp_before);
    printf("thread sp after:       %08lx\n", thread_sp_after);
    printf("handler sp:            %08lx\n", irq_sp);
    printf("registers changed:     %08lx\n", res[0]);
    printf("frame words wrong:     %08lx\n", res[1]);

    /* the interrupt happened once */
    assert(irq_count == 1);
    /* the extension is on */
    assert(csr_read(CSR_MSHWINT) == MSHWINT_EN);
    /* the caller-saved registers have their values back... */
    assert(res[0] == 0);
    /* ... and the frame holds the values they had at the interrupt */
    assert(res[1] == 0);
    /* the handler ran below the frame */
    assert(irq_sp <= thread_sp_before - FRAME_SIZE);
    /* the exit gives the frame back */
    assert(thread_sp_after == thread_sp_before);

    return 0;
}
