/*
 * Open file and print contents to stdout.
 *
 * gcc -nostdlib -o readfile readfile.S
 */

#ifdef __APPLE__
# define DOLLAR(x) $$ ## x
#else
# define DOLLAR(x) $ ## x
#endif

.section	.rodata
/* error messages */
	e_num_args: .asciz "readfile </path/to/file>\n"
	.equ e_num_args_len,(. - e_num_args)
	e_file_open: .ascii "Failed to open file "
	.equ e_fopen_len,(. - e_file_open)
	e_file_read: .ascii "Error reading from file "
	.equ e_fread_len,(. - e_file_read)

	.equ EXIT_SUCCESS,0
	.equ EXIT_FAILURE,1
	.equ SYS_READ,0
	.equ SYS_WRITE,1
	.equ SYS_OPEN,2
	.equ SYS_EXIT,60
	.equ STDOUT_FILENO,1
	.equ STDERR_FILENO,2
	.equ O_RDONLY,0

#define PAGE_SIZE 4096
.section .bss
	.lcomm BUFFER,PAGE_SIZE

.section .text

.macro PRINT_BYTE BYTE
	xorq %rax,%rax
	movb \BYTE,%al
	pushq %rax
	movq %rsp,%rsi
	movq $1,%rdx
	movq $STDOUT_FILENO,%rdi
	movq $SYS_WRITE,%rax
	syscall
	pop %rax
.endm

.macro PRINT_WORD WORD
	xorq %rax,%rax
	movw \WORD,%ax
	pushq %rax
	movq %rsp,%rsi
	movq $2,%rdx
	movq $STDOUT_FILENO,%rdi
	movq $SYS_WRITE,%rax
	syscall
	pop %rax
.endm

.global	_start

#define loc_fd_infile -8(%rbp)
#define loc_bytes_read -16(%rbp)
#define loc_ptr_infile -24(%rbp)
#define sp_offset 24

.macro GET_STR_LEN STR
	movq DOLLAR(PAGE_SIZE),%rcx
	inc %rcx
	movq \STR,%rdi
	xorb %al,%al
	repne scasb
	movq DOLLAR(PAGE_SIZE),%rbx
	subq %rcx,%rbx
	movq %rbx,%rdx
.endm

.macro PRINT_QUOTED_FILENAME
	PRINT_BYTE DOLLAR(0x22)
	movq loc_ptr_infile,%rsi
	GET_STR_LEN %rsi
	movq DOLLAR(STDERR_FILENO),%rdi
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	PRINT_WORD DOLLAR(0x0a22)
.endm

_start:
	pushq %rbp
	movq %rsp,%rbp
	subq DOLLAR(sp_offset),%rsp
	movq 8(%rbp),%rax
	cmpq DOLLAR(2),%rax
	jnz .e_argc
	movq 24(%rbp),%rdi
	movq %rdi,loc_ptr_infile
	movq DOLLAR(O_RDONLY),%rsi
/*
 * No need to zero out %rdx. The kernel will
 * determine in build_open_flags() that the
 * MODE argument is not required:
 *
 * if (flags & (O_CREAT | __O_TMPFILE))
 *  op->mode = (mode & S_IALLUGO) | S_IFREG;
 * else
 *	op->mode = 0;
 */
	mov	DOLLAR(SYS_OPEN),%rax
	syscall
	movq %rax,loc_fd_infile
	cmpq DOLLAR(0),%rax
	jl .e_open
.ra:
	movq loc_fd_infile,%rdi
	leaq BUFFER,%rsi
	movq DOLLAR(PAGE_SIZE),%rdx
	movq DOLLAR(SYS_READ),%rax
	syscall
	movq %rax,loc_bytes_read
	testq %rax,%rax
	je .reading_done
	jl .e_read
	movq DOLLAR(STDOUT_FILENO),%rdi
	leaq BUFFER,%rsi
	movq loc_bytes_read,%rdx
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	jmp .ra
.reading_done:
	addq DOLLAR(sp_offset),%rsp
	pop %rbp
	movq DOLLAR(EXIT_SUCCESS),%rdi
	movq DOLLAR(SYS_EXIT),%rax
	syscall

.e_argc:
	leaq e_num_args,%rsi
	movq DOLLAR(e_num_args_len),%rdx
	movq DOLLAR(STDERR_FILENO),%rdi
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	addq DOLLAR(sp_offset),%rsp
	pop %rbp
	movq DOLLAR(EXIT_FAILURE),%rdi
	movq DOLLAR(SYS_EXIT),%rax
	syscall

.e_open:
	leaq e_file_open,%rsi
	movq DOLLAR(e_fopen_len),%rdx
	movq DOLLAR(STDERR_FILENO),%rdi
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	PRINT_QUOTED_FILENAME
	addq DOLLAR(sp_offset),%rsp
	pop %rbp
	movq DOLLAR(EXIT_FAILURE),%rdi
	movq DOLLAR(SYS_WRITE),%rax
	syscall

.e_read:
	leaq e_file_read,%rsi
	movq DOLLAR(e_fread_len),%rdx
	movq DOLLAR(STDERR_FILENO),%rdi
	movq DOLLAR(SYS_WRITE),%rax
	syscall
	PRINT_QUOTED_FILENAME
	addq DOLLAR(sp_offset),%rsp
	pop %rbp
	movq DOLLAR(EXIT_FAILURE),%rdi
	movq DOLLAR(SYS_EXIT),%rax
	syscall
