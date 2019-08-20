/*
 * Obtain pseudo-random data from /dev/urandom and xor it with the
 * data in the input file. Write the result to xor.out and write the
 * pseudo-random data to xor.key.
 *
 * Use sparingly, as this steals precious system entropy
 *
 *
 * gcc -nostdlib -o one_time_pad one_time_pad.S
 *
 *
 */

#ifdef __APPLE__
# define DOLLAR(x) $$ ## x
#else
# define DOLLAR(x) $ ## x
#endif

.section .rodata
/* error strings */
	e_open_file: .ascii "Error opening file "
	.equ e_fopen_len,(. - e_open_file)
	e_argc_num: .ascii "one_time_pad </path/to/file>\n"
	.equ e_argc_len,(. - e_argc_num)
	e_read_file: .ascii "Error reading from file "
	.equ e_fread_len,(. - e_read_file)
	e_write_file: .ascii "Error writing to file "
	.equ e_fwrite_len,(. - e_write_file)
	e_create_file: .ascii "Error creating file "
	.equ e_fcreate_len,(. - e_create_file)

/* info strings */
	op_start_str: .ascii "Applying one-time pad to file "
	.equ op_start_str_len,(. - op_start_str)
	op_end_str: .ascii "Operation complete\n"
	.equ op_end_str_len,(. - op_end_str)
	reading_file: .ascii "Reading from file "
	.equ reading_file_len,(. - reading_file)

/* file paths */
	dev_urandom: .asciz "/dev/urandom"
	def_outfile: .asciz "xor.out"
	def_keyfile: .asciz "xor.key"

	.equ EXIT_SUCCESS,0
	.equ EXIT_FAILURE,1
	.equ SYS_READ,0
	.equ SYS_WRITE,1
	.equ SYS_OPEN,2
	.equ O_RDONLY,0
	.equ O_WRONLY,1
	.equ O_RDWR,2
	.equ O_CREAT,0x40 /* 0100 */
	.equ O_TRUNC,0x200 /* 01000 */
	.equ S_IRUSR,0x100 /* 0400 */
	.equ S_IWUSR,0x80 /* 0200 */
	.equ SYS_CLOSE,3
	.equ SYS_ACCESS,21
	.equ F_OK,0
	.equ R_OK,4
	.equ SYS_EXIT,60
	.equ STDOUT_FILENO,1
	.equ STDERR_FILENO,2
	.equ BUFFER_SIZE,8192


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

.macro PRINT_BYTE BYTE
	xorq %rax,%rax
	movb \BYTE,%al
	pushq %rax
	movq %rsp,%rsi
	movq DOLLAR(1),%rdx
	movq DOLLAR(STDOUT_FILENO),%rdi
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	pop %rax
.endm

.macro PRINT_WORD WORD
	xorq %rax,%rax
	movw \WORD,%ax
	pushq %rax
	movq %rsp,%rsi
	movq DOLLAR(2),%rdx
	movq DOLLAR(STDOUT_FILENO),%rdi
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	pop %rax
.endm

.macro PRINT_DWORD DWORD
	xorq %rax,%rax
	movl \DWORD,%eax
	pushq %rax
	movq %rsp,%rsi
	movq DOLLAR(4),%rdx
	movq DOLLAR(STDOUT_FILENO),%rdi
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	pop %rax
.endm

.macro GET_STR_LEN STR
	movq \STR,%rdi
	movq DOLLAR(0x1001),%rcx
	xorb %al,%al
	repne scasb
	movq DOLLAR(0x1000),%rbx
	subq %rcx,%rbx
	movq %rbx,%rdx
.endm

.macro PUT_RDWR_MODE
	xorq %rdx,%rdx
	movq DOLLAR(S_IRUSR),%rdx
	orq DOLLAR(S_IWUSR),%rdx
.endm

.macro ZERO REG
	xorq \REG,\REG
.endm

.globl _start

#define loc_fd_infile -8(%rbp)
#define loc_fd_outfile -16(%rbp)
#define loc_fd_keyfile -24(%rbp)
#define loc_fd_devrand -32(%rbp)
#define loc_bytes_read -40(%rbp)
#define loc_ptr_infile -48(%rbp)
_start:
	pushq %rbp
	movq %rsp,%rbp
	subq DOLLAR(48),%rsp
	movq 24(%rbp),%rax
	movq %rax,loc_ptr_infile
	movq DOLLAR(STDOUT_FILENO),%rdi
	leaq op_start_str,%rsi
	movq DOLLAR(op_start_str_len),%rdx
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	PRINT_BYTE DOLLAR(0x22)
	movq loc_ptr_infile,%rsi
	GET_STR_LEN %rsi
	movq DOLLAR(STDOUT_FILENO),%rdi
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	PRINT_WORD DOLLAR(0x0a22)
	movq loc_ptr_infile,%rdi
	movq DOLLAR(O_RDONLY),%rsi
	ZERO %rdx
	call .open_file
	cmpq DOLLAR(0),%rax
	jl .err_out
	movq %rax,loc_fd_infile
	leaq def_outfile,%rdi
	PUT_CREATION_FLAGS
	PUT_RDWR_MODE
	call .open_file
	cmpq DOLLAR(0),%rax
	jl .err_out
	movq %rax,loc_fd_outfile
	leaq def_keyfile,%rdi
	PUT_CREATION_FLAGS
	PUT_RDWR_MODE
	call .open_file
	cmpq DOLLAR(0),%rax
	jl .err_out
	movq %rax,loc_fd_keyfile
	leaq dev_urandom,%rdi
	call .open_file
	cmpq DOLLAR(0),%rax
	jl .err_out
	movq %rax,loc_fd_devrand

.read_more:
	movq loc_fd_infile,%rdi
	leaq FILE_BUFFER,%rsi
	movq DOLLAR(BUFFER_SIZE),%rdx
	movq loc_ptr_infile,%r10
	call .read_file
	cmpq DOLLAR(0),%rax
	jl .err_out
	movq %rax,loc_bytes_read

	movq loc_fd_devrand,%rdi
	leaq RAND_BUFFER,%rsi
	movq loc_bytes_read,%rdx
	leaq dev_urandom,%r10
	call .read_file
	cmpq DOLLAR(0),%rax
	jl .err_out

	movq %rax,%rcx
	dec %rcx
	leaq FILE_BUFFER,%rdi
	leaq RAND_BUFFER,%rsi
.l1:
	movb (%rdi,%rcx,1),%bl
	movb (%rsi,%rcx,1),%dl
	xorb %dl,%bl
	movb %bl,(%rdi,%rcx,1)
	dec %rcx
	cmpq DOLLAR(0),%rcx
	jge .l1
	movq loc_fd_outfile,%rdi
	leaq FILE_BUFFER,%rsi
	movq loc_bytes_read,%rdx
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	movq loc_fd_keyfile,%rdi
	leaq RAND_BUFFER,%rsi
	movq loc_bytes_read,%rdx
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	movq loc_bytes_read,%rax
	testq %rax,%rax
	jnz .read_more

	movq DOLLAR(STDOUT_FILENO),%rdi
	leaq op_end_str,%rsi
	movq DOLLAR(op_end_str_len),%rdx
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	addq DOLLAR(48),%rsp
	pop %rbp
	movq DOLLAR(EXIT_SUCCESS),%rdi
	movq DOLLAR(SYS_EXIT),%rax
	syscall

.err_out:
	addq DOLLAR(48),%rsp
	pop %rbp
	movq DOLLAR(EXIT_FAILURE),%rdi
	movq DOLLAR(SYS_EXIT),%rax
	syscall

.open_file:
	pushq %rbp
	movq %rsp,%rbp
	pushq %rdi
	movq DOLLAR(SYS_OPEN),%rax
	syscall
	cmpq DOLLAR(0),%rax
	jl .e
	pop %rdi
	pop %rbp
	ret
.e:
	pop %rdi
	call .open_file_error
	movq DOLLAR(-1),%rax
	pop %rbp
	ret

.open_file_error:
	pushq %rbp
	movq %rsp,%rbp
	pushq %rdi
	leaq e_open_file,%rsi
	movq DOLLAR(e_fopen_len),%rdx
	movq DOLLAR(STDOUT_FILENO),%rdi
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	pop %rsi
	GET_STR_LEN %rsi
	movq DOLLAR(STDOUT_FILENO),%rdi
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	PRINT_BYTE DOLLAR(0x0a)
	pop %rbp
	ret

#define _FD -8(%rbp)
#define _BUFFER -16(%rbp)
#define _TOREAD -24(%rbp)
#define _FILENAME -32(%rbp)
#define _BYTES_READ -40(%rbp)
.read_file:
	pushq %rbp
	movq %rsp,%rbp
	subq DOLLAR(40),%rsp
	movq %rdi,_FD
	movq %rsi,_BUFFER
	movq %rdx,_TOREAD
	movq %r10,_FILENAME
	movq DOLLAR(STDOUT_FILENO),%rdi
	leaq reading_file,%rsi
	movq DOLLAR(reading_file_len),%rdx
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	movq _FILENAME,%rdi
	GET_STR_LEN %rdi
	movq _FILENAME,%rsi
	movq DOLLAR(STDOUT_FILENO),%rdi
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	PRINT_BYTE DOLLAR(0x0a)
	movq _FD,%rdi
	movq _BUFFER,%rsi
	movq _TOREAD,%rdx
	movq DOLLAR(SYS_READ),%rax
	syscall
	movq %rax,_BYTES_READ
	cmpq DOLLAR(0),%rax
	jl .re
	addq DOLLAR(40),%rsp
	pop %rbp
	ret
.re:
	movq DOLLAR(STDERR_FILENO),%rdi
	leaq e_read_file,%rsi
	movq DOLLAR(e_fread_len),%rdx
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	movq _FILENAME,%rsi
	GET_STR_LEN %rsi
	movq DOLLAR(STDERR_FILENO),%rdi
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	PRINT_BYTE DOLLAR(0x0a)
	addq DOLLAR(40),%rsp
	pop %rbp
	movq DOLLAR(-1),%rax
	ret
