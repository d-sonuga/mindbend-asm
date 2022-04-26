# The functions in this unit are used by more than one of the other units
# Reading files is done by both main
#
#
# Structures and Defintions
# -------------------------
# 1. vec
#   1st 8 bytes: length
#   Everything after the length field till the max capacity * unit size, specified in initialization,
#   is considered part of the vec
# 
# Associated Functions
# --------------------
#
# utils_vec_init
# --------------
# Role
# ----
# allocate space for a vector with a certain capacity
# 
# Expected
# --------
# 1. The size of a single item in the vector is in %rdi
# 2. The max number of items the vector could possibly carry is in %rsi
#
# Result
# ------
# 1. In the case of an error, -1 in %rax, pointer to the error string in %rdi, string length in %rsi
# 2. In the case of a success, 0 in %rax, the pointer to the vector in %rdi, with it's length initialized to 0
#
# Modus Operandi
# --------------
# Todo
#
# 2. heap_string

.equ STDOUT, 1
.equ SYS_OPEN, 2

.section .data
.err_msg_file_doesnt_exist:
    .equ ERR_MSG_FILE_DOESNT_EXIST_LEN, 30
    .asciz "The input file doesn't exist.\n"

.err_msg_open_file_generic:
    .equ ERR_MSG_OPEN_FILE_GENERIC_LEN, 79
    .asciz "Something went wrong while opening the input file. (It's probably your fault).\n"

.err_msg_alloc_no_memory:
    .equ ERR_MSG_ALLOC_NO_MEMORY_LEN, 15
    .asciz "Out of memory.\n"

.err_msg_alloc_generic:
    .equ ERR_MSG_ALLOC_GENERIC, 74
    .asciz "Something went wrong while allocating memory. (It's probably your fault).\n"

.err_msg_read_file_generic:
    .equ ERR_MSG_READ_FILE_GENERIC_LEN, 79
    .asciz "Something went wrong while reading the input file. (It's probably your fault).\n"

.section .bss
.char_to_print:
    .byte 0

.input_file_info_buf:
# Space to store the struct that holds file info when the
# fstat syscall is called to determine the length of the input file
    .space 128

.section .text

# Role
# ----
# Prints ascii characters
#
# Expected
# --------
# 1. The address of the first character of the string is in %rdi
# 2. The length of the string is in %rsi
utils_print:
    movq %rdi, %r8          # Save the string address, because the file descriptor is going into %rdi
    movq %rsi, %r9          # Save the string length
    movq $1, %rax           # The system call to write
    movq $STDOUT, %rdi           
    movq %r8, %rsi
    movq %r9, %rdx
    syscall
    ret

# Role
# ----
# Finds the length of a string
#
# Expected
# --------
# 1. The address of the string is in %rdi
#
# Result
# ------
# 1. The length of the string in %rax
utils_strlen:
    movq $0, %r8                # Initializing the string index to 0
    jmp utils_strlen_loop
utils_strlen_loop:
    movb (%rdi, %r8, 1), %r9b   # Load the byte at index %r8
    cmp $0, %r9b                # Strings are null terminated, so they end with 0s
    je utils_end_strlen_loop
    incq %r8
    jmp utils_strlen_loop
utils_end_strlen_loop:
    movq %r8, %rax
    ret

# Role
# ----
# Checks if 2 strings are equal
#
# Expected
# --------
# 1. The address of the 1st string is in %rdi
# 2. The address of the 2nd string is in %rsi
#
# Result
# ------
# 1. In the case where the 2 strings are equal, 1 in %rax
# 2. Else, 0 in %rax
utils_streq:
    movq $0, %r8            # Initialize the index to 0
    movq $1, %rax           # Initialize the strings_are_equal value to true
    jmp utils_streq_loop
utils_streq_loop:
    movb (%rdi, %r8, 1), %r9b     # The value of the first string at index %r8
    movb (%rsi, %r8, 1), %r10b    # The value of the second string at index %r8
    cmp %r9b, %r10b
    jne utils_streq_loop_end_fail
    cmp $0, %r9b
    je utils_streq_loop_end_success
    incq %r8
    jmp utils_streq_loop
utils_streq_loop_end_fail:
    movq $0, %rax
    ret
utils_streq_loop_end_success:
    ret

# Role
# ----
# Prints an integer
#
# Expected
# --------
# 1. The integer to print is in %rdi
#
# Modus Operandi
# --------------
# Given input n,
# Initialize digit count to 0
# Divide n by 10
# Push the remainder on the stack
# Compare the quotient with 0
# If the quotient is 0, break
# If it is not 0, increment digit count by 1 and go back to the Push
# Repeat the following digit-count times
#   pop the value off the stack
#   Add 48 to the value
#   Print the value
# Print a newline
utils_printint:
    movq $0, %r8        # Digit count
    movq %rdi, %rax     # The number to print
    movq $10, %rdi      # The divisor
    jmp utils_printint_divide_loop
utils_printint_divide_loop:
    movq $0, %rdx
    idiv %rdi
    pushq %rdx
    incq %r8
    cmp $0, %rax    
    je utils_printint_print_loop
    jmp utils_printint_divide_loop
utils_printint_print_loop:
    leaq .char_to_print(%rip), %rdi
    popq %rsi
    addq $48, %rsi
    movq %rsi, (%rdi)
    movq $1, %rsi
    pushq %r8
    call utils_print
    popq %r8
    decq %r8
    cmp $0, %r8
    je utils_end_printint
    jmp utils_printint_print_loop
utils_end_printint:
    leaq .char_to_print(%rip), %rdi
    movq $10, (%rdi)
    movq $1, %rsi
    call utils_print
    movq $0, %rax
    ret

# Role
# ----
# Open a file
#
# Expected
# --------
# 1. The address of the filename is in %rdi
#
# Result
# ------
# 1. In the case of a success, the file descriptor in %rax, and the file size in %rsi
# 2. In the case of an error, -1 in %rax, the error string in %rdi, the error length in %rsi
.equ O_RDONLY, 0
.equ ENOENT, -2
.equ SYS_FSTAT, 5
.equ STAT_FILE_SIZE_OFFSET, 48
utils_open_file:
    movq $SYS_OPEN, %rax
    movq $O_RDONLY, %rsi
    syscall
    cmp $0, %rax
    jl utils_open_file_err          # In the case of an error, %rax holds -errno
    pushq %rax                      # Save the file descriptor
    movq %rax, %rdi
    movq $SYS_FSTAT, %rax
    leaq .input_file_info_buf(%rip), %rsi   # The location to store the stat struct
    pushq %rsi
    syscall
    cmp $0, %rax
    jl utils_open_file_err
    popq %rsi
    xor %rdi, %rdi                  # To remove leading 0s
    movl STAT_FILE_SIZE_OFFSET(%rsi), %edi
    popq %rax                       # Restore the file descriptor
    ret

utils_open_file_err:
    cmp $ENOENT, %rax
    je utils_open_file_err_file_doesnt_exist
    movq $-1, %rax
    leaq .err_msg_open_file_generic(%rip), %rdi
    movq $ERR_MSG_OPEN_FILE_GENERIC_LEN, %rsi
    ret

utils_open_file_err_file_doesnt_exist:
    leaq .err_msg_file_doesnt_exist(%rip), %rdi
    movq $ERR_MSG_FILE_DOESNT_EXIST_LEN, %rsi
    ret

# Role
# ----
# To read a file's contents into a buffer
#
# Expected
# --------
# 1. The file descriptor is in %rdi
# 2. The file address of the buffer is in %rsi
# 3. The number of bytes to read is in %rdx
#
# Result
# ------
# 1. In the case of a success, 0 is in %rax
# 2. In the case of an error, -1 is in %rax, the error string in %rdi, the error length in %rsi
.equ SYS_READ, 0
utils_read_file:
    movq $SYS_READ, %rax
    syscall
    cmp $0, %rax
    jl utils_read_file_err
    movq $0, %rax
    ret

utils_read_file_err:
    leaq .err_msg_read_file_generic(%rip), %rdi
    movq $ERR_MSG_READ_FILE_GENERIC_LEN, %rsi
    movq $-1, %rax
    ret

# Role
# ----
# Allocate space to store input file content, tokens and the expression structure
# Note: this function is to be called only once
#
# Expected
# --------
# 1. The input file descriptor is in %rdi
# 2. The number of bytes in the file is in %rsi
#
# Result
# ------
# 1. In the case of a success, the addresses of the locations to store the input file content,
#    the tokens and the expression structure are in %rax, %rdi and %rsi respectively
# 2. In the case of an error, -1 in %rax, the error string in %rdi, the error length in %rsi
#
# Definitions
# -----------
# In the comments, n means number of bytes in the file
# In the following,
#   %r14 holds the input file descriptor
#   %r15 holds the number of bytes in the input file
#   %rax either holds the syscall number for brk or the top of the data segment
#   %r8 temporarily holds the address of the input file content buffer
.equ SYS_BRK, 12
.equ ENOMEM, -12
utils_alloc_main_space:
    movq %rdi, %r14         # Saving the input file descriptor in %r14
    movq %rsi, %r15         # Saving the number of bytes in the file in %r15
    movq $SYS_BRK, %rax
    movq $-1, %rdi
    syscall                 # To find the current position of the data segment
    cmp $0, %rax
    jl utils_alloc_err      
    movq %rax, %r8          # Saving the address of the data segment top in %r8
    incq %r8                # %r8 now contains the address of the data segment top. The next address is the input file content base
    addq %r15, %rax         # Increase the data segment by file length, to create space for the file
    movq %rax, %rdi         # To become the new top of data segment
    movq $SYS_BRK, %rax     # To create space for the file contents
    syscall
    cmp $0, %rax
    jl utils_alloc_err
    movq %r8, %rax          # The base address of the input file contents
    movq $TOKEN_SIZE, %r13
    imul %r15, %r13         # Number of bytes to store n tokens (tokens can't be more than that)
    movq %rdi, %rsi
    incq %rsi               # The address to be returned as the base of the token array
    addq %r13, %rdi         # To become the new top of data segment
    movq $SYS_BRK, %rax
    syscall
    cmp $0, %rax
    jl utils_alloc_err
    movq %r8, %rax
    movq %rsi, %rdi
    ret

# Role
# ----
# Allocate space arbitrarily
#
# Expected
# --------
# 1. The amount of space in bytes is in %rdi
#
# Result
# ------
# 1. In the case of a success, the address of the allocated space is in %rax
# 2. In the case of an error, -1 in %rax, the error string in %rdi, the error length in %rsi
utils_alloc:
    pushq %rdi              # Save the number of bytes to allocate
    movq $SYS_BRK, %rax
    movq $-1, %rdi          # To get the current top of the data segment
    syscall
    cmp $0, %rax
    jl utils_alloc_err
    movq %rax, %r8
    incq %r8                # The current top of data segment + 1 will become the base of the space allocated
    popq %rdi               # Restore the number of bytes to allocate
    addq %rax, %rdi         # To become the new top of data segment
    movq $SYS_BRK, %rax
    syscall
    cmp $0, %rax
    jl utils_alloc_err
    movq %r8, %rax          # The base address of the newly allocated space
    ret    

utils_alloc_err:
    cmp $ENOMEM, %rax
    je utils_alloc_err_no_memory
    movq $-1, %rax
    leaq .err_msg_alloc_generic(%rip), %rax
    movq $ERR_MSG_ALLOC_GENERIC, %rdi
    ret

utils_alloc_err_no_memory:
    movq $-1, %rax
    leaq .err_msg_alloc_no_memory(%rip), %rax
    movq $ERR_MSG_ALLOC_NO_MEMORY_LEN, %rdi
    ret


# Role
# ----
# Saves all registers on then stack.
# To be used with utils_restore_regs because they are order dependent
utils_save_regs:
    pushq %rax
    pushq %rbx
    pushq %rcx
    pushq %rdx
    pushq %rdi
    pushq %rsi
    pushq %r8
    pushq %r9
    pushq %r10
    pushq %r11
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15

# Role
# ----
# Restores all registers previously saved with utils_save_regs
utils_restore_regs:
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %r11
    popq %r10
    popq %r9
    popq %r8
    popq %rsi
    popq %rdi
    popq %rdx
    popq %rcx
    popq %rbx
    popq %rax