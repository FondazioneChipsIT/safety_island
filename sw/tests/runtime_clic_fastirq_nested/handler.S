/* SPDX-License-Identifier: Apache-2.0 */

/* Interrupt entry of the clic_fastirq_nested test.
 *
 * With mshwint enabled every interrupt the core acknowledges moves sp down by
 * 64 bytes and, in the background, writes in that frame the 16 caller-saved
 * registers (ra, t0-t2, a0-a7, t3-t6), ra at the lowest address. The core
 * writes one frame at a time, taking 16 cycles or so, and nothing stops it
 * from acknowledging another interrupt in the meantime: that one gets its sp
 * moved but its frame is not written, and the words of the previous frame
 * that are still to be written get the registers of the new interrupt.
 * Neither the entries nor the exit save anything, they only restore.
 *
 * irq_low is the one that the thread triggers. From its handler the test
 * raises irq_high, which has a higher level and so interrupts it. There is an
 * entry of irq_low for every distance that the test tries between the
 * acknowledgment of irq_low and the one of irq_high. As in any nested
 * handler, mcause and mepc are read before the interrupts are enabled, because
 * irq_high overwrites them. The entries differ in the order and in the delay:
 *
 * low_mie_first n:   enable the interrupts, wait n nops, raise irq_high
 * low_raise_first n: raise irq_high, then enable the interrupts after n nops:
 *                    irq_high is already pending when they are
 *
 * What comes after is the same: wait for irq_high, check that its frame is
 * there and restore the context. The wait loop and the check use only
 * s-registers and the stack: if irq_high is not saved, the caller-saved
 * registers that it gives back to this handler are garbage.
 *
 * The handler uses the registers that nested_run (regs.S) sets up for it:
 *   s1 address and s2 value of the write that raises irq_high
 *   s4 address of high_count, s6 timeout of the wait
 *   s8 and s9 get mcause and mepc
 *   s7 and s10 are scratch, s10 gets the mask of the frame of irq_high
 */

#include "csr.h"

/* the frame of irq_high is right under the sp of this handler: the words of
 * the registers, that still hold the values of the thread, must be those
 * values */
.macro checkb num, idx
	li t0, 0xc0de0000 + \num
	lw t1, (-64 + 4 * \idx)(sp)
	beq t1, t0, 1f
	li t2, 1 << \num
	or s10, s10, t2
1:
.endm

.macro restore_ctx
	lw t6, 60(sp)
	lw t5, 56(sp)
	lw t4, 52(sp)
	lw t3, 48(sp)
	lw a7, 44(sp)
	lw a6, 40(sp)
	lw a5, 36(sp)
	lw a4, 32(sp)
	lw a3, 28(sp)
	lw a2, 24(sp)
	lw a1, 20(sp)
	lw a0, 16(sp)
	lw t2, 12(sp)
	lw t1, 8(sp)
	lw t0, 4(sp)
	lw ra, 0(sp)
	addi sp, sp, (4 * 16)
.endm

/* the first instruction of every entry does nothing: it is there to keep the
 * distances between the two interrupts the ones that were simulated, 1 cycle
 * longer than without it */
.macro entry_nop
.option push
.option norvc
	nop
.option pop
.endm

.macro low_mie_first nops
.global __handle_low_m\nops
.type __handle_low_m\nops,@function
__handle_low_m\nops:
	entry_nop
	csrr s8, mcause
	csrr s9, mepc
	csrsi mstatus, MIE
.option push
.option norvc
	.rept \nops
	nop
	.endr
.option pop
	sw s2, 0(s1) /* raise irq_high: it fires a few cycles from now */
	j .Llow_wait
.endm

.macro low_raise_first nops
.global __handle_low_r\nops
.type __handle_low_r\nops,@function
__handle_low_r\nops:
	entry_nop
	sw s2, 0(s1) /* raise irq_high: the interrupts are still disabled */
	csrr s8, mcause
	csrr s9, mepc
.option push
.option norvc
	.rept \nops
	nop
	.endr
.option pop
	csrsi mstatus, MIE /* irq_high fires */
	j .Llow_wait
.endm

.section .text.int
.balign 8 /* probably not needed */

/* TODO: consider __riscv_32e */
/* regular integer abi */
low_mie_first 0
low_mie_first 1
low_mie_first 2
low_mie_first 3
low_mie_first 4
low_raise_first 0
low_mie_first 8
low_mie_first 24

.Llow_wait:
1:
	lw s7, 0(s4)
	bnez s7, 2f
	addi s6, s6, -1
	bnez s6, 1b
2:
	csrci mstatus, MIE

	/* the frame of irq_high */
	li s10, 0
	checkb 1, 0
	checkb 5, 1
	checkb 6, 2
	checkb 7, 3
	checkb 10, 4
	checkb 11, 5
	checkb 12, 6
	checkb 13, 7
	checkb 14, 8
	checkb 15, 9
	checkb 16, 10
	checkb 17, 11
	checkb 28, 12
	checkb 29, 13
	checkb 30, 14
	checkb 31, 15
	la t0, frameb_mask
	sw s10, 0(t0)
	la t0, nest_done
	li t1, 1
	sw t1, 0(t0)

	csrw mcause, s8
	csrw mepc, s9
	restore_ctx
	mret

.global __handle_high
.type __handle_high,@function
__handle_high:
	call isr_high
	restore_ctx
	mret

/* an exception is a bug of the test: say which and stop, instead of looping */
.global __handle_exception
.type __handle_exception,@function
__handle_exception:
	csrr a0, mcause
	csrr a1, mepc
	csrr a2, mtval
	call exception_isr
1:
	j 1b

.section .text.int
.global clic_setup_mtvec
.type clic_setup_mtvec,@function
clic_setup_mtvec:
	la t0, __clic_vector_table
	or t0, t0, 1 /* enable vectored mode TODO: should be clic mode */
	csrw mtvec, t0
	ret

.section .text.int
.global clic_setup_mtvt
.type clic_setup_mtvt,@function
clic_setup_mtvt:
	la t0, __clic_vector_table
	or t0, t0, 1 /* enable vectored mode TODO: should be clic mode */
	csrw 0x307, t0 /* mtvt=0x307 */
	ret

.section .text.vectors
software_handler:
	j software_handler
timer_handler:
	j timer_handler
external_handler:
	j external_handler
__no_irq_handler:
	j __no_irq_handler

.section .text.vectors
.option norvc
.balign 1024
.global __clic_vector_table
__clic_vector_table:
	j __handle_exception
	j __no_irq_handler
	j __no_irq_handler
	j software_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j timer_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j external_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __handle_low_m0 /* 23 */
	j __handle_low_m1
	j __handle_low_m2
	j __handle_low_m3
	j __handle_low_m4
	j __handle_low_r0
	j __handle_low_m8
	j __handle_low_m24 /* 30 */
	j __handle_high /* 31 */
