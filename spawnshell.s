.section	.rodata
	PATH_TO_SHELL: .asciz "/bin/sh"
	.align 16
	.equ SYS_EXECVE,59

.section .text

.macro NULL_PTR_BX
	xorq	%rax,%rax
	pushq	%rax
	movq	%rsp,%rbx
.endm

.global		_start

_start:
	NULL_PTR_BX
	mov		$PATH_TO_SHELL,%rdi
	movq	%rbx,%rsi
	movq	%rbx,%rdx
	movb	$SYS_EXECVE,%al
	syscall
