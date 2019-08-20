#ifdef __APPLE__
# define DOLLAR(x) $$ ## x
#else
# define DOLLAR(x) $ ## x
#endif

.section .rodata
	bin_sh: .ascii "/bin/sh"

	.equ SYS_EXECVE,59

.section .text

.macro NULL_PTR_BX
	xorq	%rax,%rax
	pushq	%rax
	movq	%rsp,%rbx
.endm

.global	_start

_start:
	pushq %rbp
	movq %rsp,%rbp
	NULL_PTR_BX
	leaq bin_sh,%rdi
	movq %rbx,%rsi
	movq %rbx,%rdx
	movq DOLLAR(SYS_EXECVE),%rax
	syscall
