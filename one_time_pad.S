#######################################################################
#  Open file specified by user, obtain random data of same length as  #
#  file from /dev/urandom, xor it together and write the result into  #
#  ./xor.out. Write the random data to ./xor.key                      #
#######################################################################

#ifdef __APPLE__
# define DOLLAR(x) $$ ## x
#else
# define DOLLAR(x) $ ## x
#endif

#define VARIABLE(x) .globl x ; .type x, @object ; x:

.section .rodata
	DRANDOM: .asciz "/dev/urandom"
	E_DRANDOM_OPEN: .asciz "Failed to open /dev/urandom\n"
	.equ E_DRANDOM_LEN,(. - E_DRANDOM_OPEN)

	DEFAULT_OUTFILE: .asciz "xor.out"
	DEFAULT_KEYFILE: .asciz "xor.key"

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

	.equ EXIT_SUCCESS,0
	.equ EXIT_FAILURE,1
	.equ SYS_READ,0
	.equ SYS_WRITE,1
	.equ SYS_OPEN,2
# File open flags
	.equ O_RDONLY,0
	.equ O_WRONLY,1
	.equ O_RDWR,2
	.equ O_CREAT,0x100
	.equ O_TRUNC,0x200
# File permission modes
	.equ S_IWUSR,0x200
	.equ S_IRUSR,0x400
	.equ SYS_CLOSE,3
	.equ SYS_ACCESS,21
# Access permission flags
	.equ F_OK,0
	.equ R_OK,4
	.equ SYS_EXIT,60
	.equ STDOUT_FILENO,1
	.equ BUFFER_SIZE,8192

.section .data
	VARIABLE(fd_infile) .int -1
	VARIABLE(fd_outfile) .int -1
	VARIABLE(fd_keyfile) .int -1
	VARIABLE(fd_drandom) .int -1
	VARIABLE(bytes_read) .int 0
	VARIABLE(ptr_infile) .long 0
.align 4,0

.section .bss
	.lcomm RAND_BUFFER,8192
	.lcomm FILE_BUFFER,8192

.section .text
.macro PUT_CREATION_FLAGS
	xorq %rsi,%rsi
	movq DOLLAR(O_RDWR),%rsi
	orq DOLLAR(O_CREAT),%rsi
	orq DOLLAR(O_TRUNC),%rsi
.endm

.macro PUT_RDWR_MODE
	xorq %rdx,%rdx
	movq DOLLAR(S_IRUSR),%rdx
	orq DOLLAR(S_IWUSR),%rdx
.endm

.macro OPEN_FILE _FILE_LOC,_OPEN_FLAGS,_OPEN_MODE,_EMSG,_EMSG_LEN
	movq \_FILE_LOC,%rdi
	movq \_OPEN_FLAGS,%rsi
	movq \_OPEN_MODE,%rdx
	movq DOLLAR(SYS_OPEN),%rax
	syscall
	ZERO_REG %r8
	cmpq DOLLAR(0),%rax
	setl %r8b
	movq \_EMSG,%rsi
	movq \_EMSG_LEN,%rdx
	cmpb DOLLAR(1),%r8b
	je .err_out
.endm

.macro CLOSE_FILE _FD_LOC
	movq (\_FD_LOC),%rdi
	movq DOLLAR(SYS_CLOSE),%rax
	syscall
.endm

.macro READ_BLOCK _FD,_BUFFER,_BUFFER_SIZE
	movq \_FD,%rdi
	movq \_BUFFER,%rsi
	movq \_BUFFER_SIZE,%rdx
	movq DOLLAR(SYS_READ),%rax
	syscall
	ZERO_REG %r8
	cmpq DOLLAR(0),%rax
	setl %r8b
	movq DOLLAR(E_FILE_READ),%rsi
	movq DOLLAR(E_FREAD_LEN),%rdx
	cmpb DOLLAR(1),%r8b
	je .err_out
.endm

.macro WRITE_TO_FILE _FD,_BUFFER,_NUM_BYTES
	movq \_FD,%rdi
	movq \_BUFFER,%rsi
	movq \_NUM_BYTES,%rdx
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	ZERO_REG %r8
	cmpq \_NUM_BYTES,%rax
	setl %r8b
	movq DOLLAR(E_FILE_WRITE),%rsi
	movq DOLLAR(E_FWRITE_LEN),%rdx
	cmpb DOLLAR(1),%r8b
	je .err_out
.endm

.macro CHECK_FILE _FILE
	movq \_FILE,%rdi
	movq DOLLAR(F_OK),%rsi
	movq DOLLAR(SYS_ACCESS),%rax
	syscall
	ZERO_REG %r8
	testq	%rax,%rax
	setne %r8b
	movq DOLLAR(E_ACCESS_EXIST),%rsi
	movq DOLLAR(E_ACCESS_EXIST_LEN),%rdx
	cmpb DOLLAR(1),%r8b
	je .err_out
	movq DOLLAR(R_OK),%rsi
	movq DOLLAR(SYS_ACCESS),%rax
	syscall
	ZERO_REG %r8
	testq %rax,%rax
	setne %r8b
	movq DOLLAR(E_ACCESS_READ),%rsi
	movq DOLLAR(E_ACCESS_READ_LEN),%rdx
	cmpb DOLLAR(1),%r8b
	je .err_out
.endm

.macro PUSH_REGS
	pushq %rbx
	pushq %rcx
	pushq %rdx
	pushq %r8
	pushq %r9
	pushq %r10
	pushq %r11
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
.endm

.macro POP_REGS
	pop %r15
	pop %r14
	pop %r13
	pop %r12
	pop %r11
	pop %r10
	pop %r9
	pop %r8
	pop %rdx
	pop %rcx
	pop %rbx
.endm

# @rdi: name of env var
# @rsi: starting stack address to begin search
# @rdx: number of bytes to compare
.get_env_var:
	movq DOLLAR(1),%rcx
	pushq %rdx
	pushq %rsi
	pushq %rdi
.continue_search:
	movq 8(%rsp),%rdx
	movq (%rdx,%rcx,8),%rsi
	testq %rsi,%rsi
	je .get_env_var_notfound
	movq (%rsp),%rdi
	movq 16(%rsp),%rdx
	pushq %rsi
	pushq %rcx
	call cmp_str
	pop %rcx
	testq %rax,%rax
	je .extract_value
	inc %rcx
	jmp .continue_search
.get_env_var_notfound:
	movq DOLLAR(-1),%rax
	ret
.extract_value:
	pop %rdi
	movq DOLLAR(0),%rcx
	movb DOLLAR(0x3d),%rax
	scasb repne
	inc %rcx
	movq %rcx,value_offset
	movq DOLLAR(0),%rax
	movq %rax,%rcx
	scasb repne
	inc %rcx
	

.macro GET_ENV_VAR _ENV_STR
	movq \_ENV_STR,%rdi
	movq DOLLAR(4),%rcx
.continue_searching:
	movq (%rsp,%rcx,8),%rsi
	call .cmp_str
	testq %rax,%rax
	
.endm

.macro ZERO_REG _REG
	xorq \_REG,\_REG
.endm

.globl _start

_start:
	movq (%rsp),%rdi
	ZERO_REG %r8
	cmpq DOLLAR(2),%rdi
	setne %r8b
	movq DOLLAR(E_ARGC),%rsi
	movq DOLLAR(E_ARGC_LEN),%rdx
	cmpb DOLLAR(1),%r8b
	je .err_out
	leaq 0x10(%rsp),%rax
	movq %rax,(ptr_infile)
	CHECK_FILE %rax
	PUT_CREATION_FLAGS
	PUT_RDWR_MODE
	OPEN_FILE DOLLAR(DEFAULT_OUTFILE),%rsi,%rdx,DOLLAR(E_DRANDOM_OPEN),DOLLAR(E_DRANDOM_LEN)
	movq %rax,(fd_outfile)
	PUT_CREATION_FLAGS
	PUT_RDWR_MODE
	OPEN_FILE DOLLAR(DEFAULT_KEYFILE),%rsi,%rdx,DOLLAR(E_FILE_OPEN),DOLLAR(E_FOPEN_LEN)
	movq %rax,(fd_keyfile)
	ZERO_REG %rdx
	movq (ptr_infile),%rdi
	OPEN_FILE %rdi,DOLLAR(O_RDONLY),%rdx,DOLLAR(E_FILE_OPEN),DOLLAR(E_FOPEN_LEN)
	movq %rax,(fd_infile)
.do_file_xor:
	ZERO_REG %rdx
	OPEN_FILE DOLLAR(DRANDOM),DOLLAR(O_RDONLY),%rdx,DOLLAR(E_DRANDOM_OPEN),DOLLAR(E_DRANDOM_LEN)
	movq %rax,(fd_drandom)
	movq (fd_infile),%rdi
.read_more:
	READ_BLOCK %rdi,DOLLAR(FILE_BUFFER),DOLLAR(BUFFER_SIZE)
	testq %rax,%rax
	je .xor_done
	movq %rax,(bytes_read)
	movq (fd_drandom),%rdi
	movq %rax,%rdx
	READ_BLOCK %rdi,DOLLAR(RAND_BUFFER),%rdx
	movq (bytes_read),%rcx
	dec %rcx
.xor_loop:
	movq DOLLAR(FILE_BUFFER),%rdi
	movq DOLLAR(RAND_BUFFER),%rsi
	movb (%rdi,%rcx,),%bl
	movb (%rsi,%rcx,),%dl
	xorb %bl,%dl
	movb %dl,(%rdi,%rcx,)
	dec %rcx
	cmpq DOLLAR(0),%rcx
	jge .xor_loop
	movq (fd_outfile),%rdi
	movq (bytes_read),%rdx
	WRITE_TO_FILE %rdi,DOLLAR(FILE_BUFFER),%rdx
	movq (fd_keyfile),%rdi
	movq (bytes_read),%rdx
	WRITE_TO_FILE %rdi,DOLLAR(RAND_BUFFER),%rdx
	movq (fd_infile),%rdi
	jmp .read_more
.xor_done:
	CLOSE_FILE fd_infile
	CLOSE_FILE fd_outfile
	CLOSE_FILE fd_keyfile
	CLOSE_FILE fd_drandom
	movq DOLLAR(STDOUT_FILENO),%rdi
	movq DOLLAR(OPERATION_COMPLETE),%rsi
	movq DOLLAR(OPERATION_COMPLETE_LEN),%rdx
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	movq DOLLAR(EXIT_SUCCESS),%rdi
	movq DOLLAR(SYS_EXIT),%rax
	syscall
.err_out:
	movq DOLLAR(STDOUT_FILENO),%rdi
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	movq DOLLAR(EXIT_FAILURE),%rdi
	movq DOLLAR(SYS_EXIT),%rax
	syscall

.cmp_str:
	PUSH_REGS
	GET_STR_LEN %rdi
	movq %rax,%rbx
	GET_STR_LEN %rsi
	movq %rax,%rcx
	cmpq %rcx,%rbx
	je .cmp_str_l2
	movq DOLLAR(1),%rax
.cmp_str_l1:
	POP_REGS
	ret
.cmp_str_l2:
	dec %rcx
.cmp_str_l3:
	movb (%rdi,%rcx,1),%r8
	movb (%rsi,%rcx,1),%r9
	cmpb %r8,%r9
	jne .cmp_str_l1
	dec %rcx
	cmpq DOLLAR(0),%rcx
	jge .cmp_str_l3
	movq DOLLAR(0),%rax
	jmp .cmp_str_l1
