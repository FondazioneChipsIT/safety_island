/* SPDX-License-Identifier: Apache-2.0 */

/* Interrupted code of the clic_fastirq_nested test.
 *
 * void nested_run(void)
 *
 * 1. Fill the 16 caller-saved registers (ra, t0-t2, a0-a7, t3-t6) with
 *    0xc0de0000 + the number of the register, and the 36 words under sp with
 *    0xdeadbeef, so that a frame that is not written is not mistaken for one
 *    that is.
 * 2. Trigger irq_low by lowering mintthresh below its level and wait until
 *    its handler (handler.S) is done. The handler raises irq_high, which
 *    interrupts it.
 * 3. Check the registers and the 16 words right under sp, where the entry of
 *    irq_low leaves the context of this code: thread_regs_mask and
 *    thread_frame_mask get bit n set if register xn, or its word in the frame,
 *    does not hold its value.
 *
 * The handler uses some s-registers that this code sets up for it before the
 * trigger, so they are saved here:
 *   s1 address and s2 value of the write that raises irq_high
 *   s4 address of high_count, s6 timeout of the wait of the handler
 * The handler overwrites s6-s10. s0, s5 and s11 are the ones of the wait loop
 * of this code, that the handler does not touch.
 */

#include "csr.h"

.macro fill reg, num
	li \reg, 0xc0de0000 + \num
.endm

/* idx: position of the register in the frame */
.macro check reg, num, idx
	li s9, 0xc0de0000 + \num
	beq \reg, s9, 1f
	li s10, 1 << \num
	or s7, s7, s10
1:
	lw s10, (-64 + 4 * \idx)(sp)
	beq s10, s9, 2f
	li s10, 1 << \num
	or s8, s8, s10
2:
.endm

.section .text
.balign 4
.global nested_run
.type nested_run,@function
nested_run:
	addi sp, sp, -64
	sw ra, 60(sp)
	sw s0, 56(sp)
	sw s1, 52(sp)
	sw s2, 48(sp)
	sw s3, 44(sp)
	sw s4, 40(sp)
	sw s5, 36(sp)
	sw s6, 32(sp)
	sw s7, 28(sp)
	sw s8, 24(sp)
	sw s9, 20(sp)
	sw s10, 16(sp)
	sw s11, 12(sp)

	/* poison the two frames that the interrupts are going to write */
	li t1, 0xdeadbeef
	addi t2, sp, -144
1:
	sw t1, 0(t2)
	addi t2, t2, 4
	bne t2, sp, 1b

	/* what the handler needs */
	la s5, nest_done
	la s4, high_count
	la t1, high_trigger_addr
	lw s1, 0(t1)
	la t1, high_trigger_val
	lw s2, 0(t1)
	li s6, 4000
	li s11, 4000

	fill ra, 1
	fill t0, 5
	fill t1, 6
	fill t2, 7
	fill a0, 10
	fill a1, 11
	fill a2, 12
	fill a3, 13
	fill a4, 14
	fill a5, 15
	fill a6, 16
	fill a7, 17
	fill t3, 28
	fill t4, 29
	fill t5, 30
	fill t6, 31

	csrwi CSR_MINTTHRESH, 0xb /* 0xb < level of irq_low: it fires */
1:
	lw s0, 0(s5)
	bnez s0, 2f
	addi s11, s11, -1
	bnez s11, 1b
2:

	li s7, 0
	li s8, 0
	check ra, 1, 0
	check t0, 5, 1
	check t1, 6, 2
	check t2, 7, 3
	check a0, 10, 4
	check a1, 11, 5
	check a2, 12, 6
	check a3, 13, 7
	check a4, 14, 8
	check a5, 15, 9
	check a6, 16, 10
	check a7, 17, 11
	check t3, 28, 12
	check t4, 29, 13
	check t5, 30, 14
	check t6, 31, 15
	la t0, thread_regs_mask
	sw s7, 0(t0)
	la t0, thread_frame_mask
	sw s8, 0(t0)

	lw ra, 60(sp)
	lw s0, 56(sp)
	lw s1, 52(sp)
	lw s2, 48(sp)
	lw s3, 44(sp)
	lw s4, 40(sp)
	lw s5, 36(sp)
	lw s6, 32(sp)
	lw s7, 28(sp)
	lw s8, 24(sp)
	lw s9, 20(sp)
	lw s10, 16(sp)
	lw s11, 12(sp)
	addi sp, sp, 64
	ret
