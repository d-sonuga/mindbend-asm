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

.section .bss
.char_to_print:
    .byte 0

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