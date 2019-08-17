# Open file, print contents to stdout

.section	.rodata
	ARGC_ERROR: .asciz "Arguments required...\n"
	.align 16
	.equ ARGC_ELEN,(. - ARGC_ERROR)
	OPEN_ERROR: .asciz "Error opening file...\n"
	.align 16
	.equ OPEN_ELEN,(. - OPEN_ERROR)
	
	.equ EXIT_SUCCESS,0
	.equ EXIT_FAILURE,1
	.equ SYS_READ,0
	.equ SYS_WRITE,1
	.equ SYS_OPEN,2
	.equ SYS_EXIT,60
	.equ STDOUT_FILENO,1
	.equ O_RDONLY,0
	.equ RBLOCK_SIZE,0x1000

.macro PRELOGUE
	andq	$-16,%rsp
	pushq	%rbp
	movq	%rsp,%rbp
.endm

.macro EPILOGUE
	pop %rbp
.endm

.global	_start

_start:
	PRELOGUE
	movq	0x8(%rsp),%rax
	movq	$ARGC_ERROR,%rsi
	movq	$ARGC_ELEN,%rdx
	cmpb	$2,%al
	jl	.ERROR
	leaq	0x10(%rsp),%rsi
	movq	8(%rsi),%rdi
	mov	$O_RDONLY,%rsi
	mov	$0,%rdx
	mov	$SYS_OPEN,%rax
	syscall
	movq	%rax,%r8
	movq	$OPEN_ERROR,%rsi
	movq	$OPEN_ELEN,%rdx
	cmpb	$3,%al
	jl	.ERROR

.READMORE:
	subq	$RBLOCK_SIZE,%rsp
	movq	%r8,%rdi
	movq	%rsp,%rsi
	movq	$RBLOCK_SIZE,%rdx
	mov	$SYS_READ,%rax
	syscall

	movq	%rax,%r9
	xorq	%rbx,%rbx
	testq	%r9,%r9
	setbe	%bl

	mov	$STDOUT_FILENO,%rdi
	movq	%rax,%rdx
	mov	$SYS_WRITE,%rax
	push	%r8
	push	%r9
	push	%rbx
	syscall
	pop	%rbx
	pop	%r9
	pop	%r8
	cmpb	$1,%bl
	jne	.READMORE
	movq	$EXIT_SUCCESS,%rdi
.DONE:
	EPILOGUE
	mov	$SYS_EXIT,%rax
	syscall
.ERROR:
	mov	$STDOUT_FILENO,%rdi
	mov	$SYS_WRITE,%rax
	syscall
	movq	$EXIT_FAILURE,%rax
	jmp	.DONE
