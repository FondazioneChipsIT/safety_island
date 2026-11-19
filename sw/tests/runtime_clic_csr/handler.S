/* SPDX-License-Identifier: Apache-2.0 */

/* Exception entry of the clic_csr test.
 *
 * The core is in CLIC mode, so every synchronous exception jumps to the base
 * address of mtvec, which is the first entry of the table below. The entry
 * jumps to exception_handler (clic-csr.c).
 */

.section .text.int
.global clic_setup_mtvec
.type clic_setup_mtvec,@function
clic_setup_mtvec:
	la t0, __exception_vector
	or t0, t0, 1 /* enable vectored mode (the core keeps the CLIC mode) */
	csrw mtvec, t0
	ret

.section .text.vectors
.option norvc
.balign 1024
.global __exception_vector
__exception_vector:
	j exception_handler
