.section .rodata
	DRANDOM: .asciz "/dev/urandom"
	.align 16
	E_ARGC: .asciz "xor </path/to/file>\n"
	.equ E_ARGC_LEN,(. - E_ARGC)
	.align 16
	E_FILE_EXIST: .asciz "File does not exist!\n"
	.align 16
	.equ E_FEXIST_LEN,(. - E_FILE_EXIST)
	E_FILE_READ: .asciz "No permission to read file!\n"
	.align 16
	.equ E_FREAD_LEN,(. - E_FILE_READ)

	.equ EXIT_SUCCESS,0
	.equ EXIT_FAILURE,1
	.equ SYS_READ,0
	.equ SYS_WRITE,1
	.equ SYS_OPEN,2
	.equ O_RDONLY,0
	.equ SYS_CLOSE,3
	.equ SYS_ACCESS,21
	.equ F_OK,0
	.equ R_OK,4
	.equ SYS_EXIT,60
	.equ STDOUT_FILENO,1

.section .bss
	.lcomm RAND_BUFFER,8192
	.lcomm FILE_BUFFER,8192

.section .text

.macro NULL_PTR_BX
	xorq %rax,%rax
	pushq %rax
	movq	%rsp,%rbx
.endm

.macro CHECK_FILE __file
	movq \__file,%rdi
	movq $F_OK,%rsi
	movq $SYS_ACCESS,%rax
	syscall
	testq	%rax,%rax
	setbe	%cl
	movq $E_FILE_EXIST,%rsi
	movq $E_FEXIST_LEN,%rdx
	cmpb $1,%cl
	je $ERR_OUT
.endm

.macro PRELOGUE
	andq $-16,%rsp
	pushq %rbp
	movq %rsp,%rbp
.endm

.global _start

_start:
	movq (%rsp),%rdi
	cmpb $2,%dl
	setbne %cl
	movq $E_ARGC,%rsi
	movq $E_ARGC_LEN,%rdx
	cmpb $1,%cl
	je $ERR_OUT
	leaq $8(%rsp),%rdi
	movq $F_OK,%rsi
	movq $SYS_ACCESS,%rax
	pushq %rdi
	syscall
	testq %rax,%rax
	setbne %cl
	movq $E_FILE_EXIST,%rsi
	movq $E_FEXIST_LEN,%rdx
	cmpb $1,%cl
	je $ERR_OUT
	pop %rdi

# TODO
# Read blocks of DRANDOM and input file to
# RAND_BUFFER and FILE_BUFFER respectively.
# Xor each byte and store result in
# OUT_BUFFER. Write OUT_BUFFER to file.

ERR_OUT:
	movq $STDOUT_FILENO,%rdi
	movq $SYS_WRITE,%rax
	syscall
	movq $EXIT_FAILURE,%rdi
	movq $SYS_EXIT,%rax
	syscall
