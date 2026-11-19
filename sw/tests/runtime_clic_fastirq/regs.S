/* SPDX-License-Identifier: Apache-2.0 */

/* Interrupted code of the clic_fastirq test.
 *
 * void fastirq_run(uint32_t res[2], volatile uint32_t *irq_count)
 *
 * 1. Fill the 16 caller-saved registers (ra, t0-t2, a0-a7, t3-t6) with
 *    0xc0de0000 + the number of the register.
 * 2. Trigger the interrupt by lowering mintthresh below its level and wait
 *    until the handler has counted it.
 * 3. Check the registers and the 16 words right under sp: that is where the
 *    interrupt entry leaves the context of the interrupted code, in the same
 *    order (ra, t0-t2, a0-a7, t3-t6, from the lowest address), no matter if
 *    it is done by the hardware or by the handler.
 *
 * res[0] bit n set if register xn does not hold its value after the interrupt
 * res[1] bit n set if the word of register xn in the frame is not its value
 */

#include "csr.h"

.macro fill reg, num
	li \reg, 0xc0de0000 + \num
.endm

/* idx: position of the register in the frame */
.macro check reg, num, idx
	li s3, 0xc0de0000 + \num
	beq \reg, s3, 1f
	li s4, 1 << \num
	or s5, s5, s4
1:
	lw s4, (-64 + 4 * \idx)(sp)
	beq s4, s3, 2f
	li s4, 1 << \num
	or s6, s6, s4
2:
.endm

.section .text
.balign 4
.global fastirq_run
.type fastirq_run,@function
fastirq_run:
	addi sp, sp, -32
	sw ra, 28(sp)
	sw s0, 24(sp)
	sw s1, 20(sp)
	sw s2, 16(sp)
	sw s3, 12(sp)
	sw s4, 8(sp)
	sw s5, 4(sp)
	sw s6, 0(sp)

	mv s2, a0 /* res */
	mv s1, a1 /* irq_count */

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

	csrwi CSR_MINTTHRESH, 0xb /* 0xb < level of the interrupt: it fires */
1:
	lw s0, 0(s1)
	beqz s0, 1b

	li s5, 0
	li s6, 0
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
	sw s5, 0(s2)
	sw s6, 4(s2)

	lw ra, 28(sp)
	lw s0, 24(sp)
	lw s1, 20(sp)
	lw s2, 16(sp)
	lw s3, 12(sp)
	lw s4, 8(sp)
	lw s5, 4(sp)
	lw s6, 0(sp)
	addi sp, sp, 32
	ret
