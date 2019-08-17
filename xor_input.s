.section .rodata
	DRANDOM: .asciz "/dev/urandom"

	E_DRANDOM_OPEN: .asciz "Failed to open /dev/urandom\n"
	.equ E_DRANDOM_LEN,(. - E_DRANDOM_OPEN)

	DEFAULT_OUTFILE: .asciz "xor.out"

	E_ARGC: .asciz "xor </path/to/file>\n"
	.equ E_ARGC_LEN,(. - E_ARGC)

	E_ACCESS_EXIST: .asciz "File does not exist\n"
	.equ E_ACCESS_EXIST_LEN,(. - E_ACCESS_EXIST)

	E_ACCESS_READ: .asciz "No permission to read file\n"
	.equ E_ACCESS_READ_LEN,(. - E_ACCESS_READ)

	E_FILE_READ: .asciz "Error reading from file\n"
	.equ E_FREAD_LEN,(. - E_FILE_READ)

	E_FILE_WRITE: .asciz "Error writing to file\n"
	.equ E_FWRITE_LEN,(. - E_FILE_WRITE)

	E_FILE_CREATE: .asciz "Failed to create xor.out\n"
	.equ E_FCREATE_LEN,(. - E_FILE_CREATE)

	E_FILE_OPEN: .asciz "Failed to open file\n"
	.equ E_FOPEN_LEN,(. - E_FILE_OPEN)

	OPERATION_COMPLETE: .asciz "Finished XORing file\n"
	.equ OPERATION_COMPLETE_LEN,(. - OPERATION_COMPLETE)

	.align 16

	.equ EXIT_SUCCESS,0
	.equ EXIT_FAILURE,1
	.equ SYS_READ,0
	.equ SYS_WRITE,1
	.equ SYS_OPEN,2
	.equ O_RDONLY,0
	.equ O_WRONLY,1
	.equ O_RDWR,2
	.equ O_CREAT,0x100
	.equ O_TRUNC,0x200
	.equ S_IRUSR,0x400
	.equ SYS_CLOSE,3
	.equ SYS_ACCESS,21
	.equ F_OK,0
	.equ R_OK,4
	.equ SYS_EXIT,60
	.equ STDOUT_FILENO,1
	.equ BUFFER_SIZE,8192

	.align 16

.section .bss
	.lcomm RAND_BUFFER,8192
	.lcomm FILE_BUFFER,8192

.section .text

.macro PUT_CREATION_FLAGS
	xorq %rsi,%rsi
	movq $O_RDWR,%rsi
	orq $O_CREAT,%rsi
	orq $O_TRUNC,%rsi
.endm

.macro OPEN_FILE _FILE_LOC,_OPEN_FLAGS,_OPEN_MODE,_EMSG,_EMSG_LEN
	movq \_FILE_LOC,%rdi
	movq \_OPEN_FLAGS,%rsi
	movq \_OPEN_MODE,%rdx
	movq $SYS_OPEN,%rax
	syscall
	cmpq $0,%rax
	setl %cl
	movq \_EMSG,%rsi
	movq \_EMSG_LEN,%rdx
	cmpb $1,%cl
	je .ERR_OUT
.endm

.macro READ_BLOCK _FD, _BUFFER, _BUFFER_SIZE
	movq \_FD,%rdi
	movq \_BUFFER,%rsi
	movq \_BUFFER_SIZE,%rdx
	movq $SYS_READ,%rax
	syscall
	cmpq $0,%rax
	setl %cl
	movq $E_FILE_READ,%rsi
	movq $E_FREAD_LEN,%rdx
	cmpb $1,%cl
	je .ERR_OUT
.endm

.macro WRITE_TO_FILE _FD, _BUFFER, _NUM_BYTES
	movq \_FD,%rdi
	movq \_BUFFER,%rsi
	movq \_NUM_BYTES,%rdx
	movq $SYS_WRITE,%rax
	syscall
	cmpq \_NUM_BYTES,%rax
	setl %cl
	movq $E_FILE_WRITE,%rsi
	movq $E_FWRITE_LEN,%rdx
	cmpb $1,%cl
	je .ERR_OUT
.endm

.macro CHECK_FILE _FILE
	movq \_FILE,%rdi
	movq $F_OK,%rsi
	movq $SYS_ACCESS,%rax
	syscall
	testq	%rax,%rax
	setne	%cl
	movq $E_ACCESS_EXIST,%rsi
	movq $E_ACCESS_EXIST_LEN,%rdx
	cmpb $1,%cl
	je .ERR_OUT
	movq $R_OK,%rsi
	movq $SYS_ACCESS,%rax
	syscall
	testq %rax,%rax
	setne %cl
	movq $E_ACCESS_READ,%rsi
	movq $E_ACCESS_READ_LEN,%rdx
	cmpb $1,%cl
	je .ERR_OUT
.endm

.global _start

_start:
	movq (%rsp),%rdi
	cmpb $2,%dl
	setne %cl
	movq $E_ARGC,%rsi
	movq $E_ARGC_LEN,%rdx
	cmpb $1,%cl
	je .ERR_OUT
	leaq 8(%rsp),%rdi
	pushq %rdi
	CHECK_FILE %rdi
	PUT_CREATION_FLAGS
	OPEN_FILE $DEFAULT_OUTFILE, %rsi, $S_IRUSR, $E_DRANDOM_OPEN, $E_DRANDOM_LEN
	movq %rax,%r8
	pop %rdi
	xorq %rdx,%rdx
	OPEN_FILE %rdi, $O_RDONLY, %rdx, $E_FILE_OPEN, $E_FOPEN_LEN
.do_file_xor:
	pushq %r8
	pushq %r9
	xorq %rdx,%rdx
	OPEN_FILE $DRANDOM, $O_RDONLY, %rdx, $E_DRANDOM_OPEN, $E_DRANDOM_LEN
	movq %rax,%r15
	movq (%rsp),%rdi
.read_more:
	READ_BLOCK %rdi, $FILE_BUFFER, $BUFFER_SIZE
	testq %rax,%rax
	je .xor_done
	movq %rax,%rdx
	pushq %rax
	movq 16(%rsp),%rdi
	READ_BLOCK %rdi, $RAND_BUFFER, %rdx
	pushq %rdx
	pop %rcx
	dec %rcx
#
# STACK:
#
# [ fd xor.out      ]
# [ fd input file   ]
# [ #bytes read from in file ] <= %rsp

.xor_loop:
	movq $FILE_BUFFER,%rdi
	movq $RAND_BUFFER,%rsi
	movb (%rdi,%rcx,),%bl
	movb (%rsi,%rcx,),%dl
	xorb %bl,%dl
	movb %dl,(%rdi,%rcx,)
	dec %rcx
	testq %rcx,%rcx
	jne .xor_loop
	pop %rdx
	movq 8(%rsp),%rdi
	WRITE_TO_FILE %rdi, $FILE_BUFFER, %rdx
	jmp .read_more

.xor_done:
	movq $STDOUT_FILENO,%rdi
	movq $OPERATION_COMPLETE,%rsi
	movq $OPERATION_COMPLETE_LEN,%rdx
	movq $SYS_WRITE,%rax
	syscall
	movq $EXIT_SUCCESS,%rdi
	movq $SYS_EXIT,%rax
	syscall
	
.ERR_OUT:
	movq $STDOUT_FILENO,%rdi
	movq $SYS_WRITE,%rax
	syscall
	movq $EXIT_FAILURE,%rdi
	movq $SYS_EXIT,%rax
	syscall
