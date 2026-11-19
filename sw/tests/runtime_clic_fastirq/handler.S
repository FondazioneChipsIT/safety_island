/* SPDX-License-Identifier: Apache-2.0 */

/* Interrupt entry of the clic_fastirq test.
 *
 * With mshwint enabled the core does the entry on its own: it moves sp down
 * by 64 bytes and, in the background, writes the 16 caller-saved registers
 * (ra, t0-t2, a0-a7, t3-t6) in the frame it opens, ra at the lowest address.
 * The handler does not save anything, it only restores them and gives the
 * 64 bytes back.
 *
 * The core writes the frame from the highest address to the lowest, and it
 * does not wait for it to be done: the handler has to take longer than that
 * before it reads the frame back. That is why the registers are restored from
 * t6 to ra, the order in which the core writes them, and why clic_isr comes
 * first. A handler shorter than the saving would read a frame still to be
 * written.
 */

.section .text.int
.balign 8 /* probably not needed */

/* TODO: consider __riscv_32e */
/* regular integer abi */
.global __handle_clic_int
.type __handle_clic_int,@function
__handle_clic_int:
	call clic_isr

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

	mret

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
default_exception_handler:
	j default_exception_handler
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
	j default_exception_handler
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
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __handle_clic_int
