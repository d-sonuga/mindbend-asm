# Role
# ----
# Turn raw input into a vector of tokens
#
# Expected
# --------
# 1. A pointer to the raw input is stored in %rdi
# 2. The length of the buffer content is stored in %rsi
# 3. The address of the token buffer is in %rdx
#
# Result
# ------
# 1. In the case of an error, -1 in %rax, a pointer to the error string in %rdi, the string length in %rsi
# 2. In the case of a success, the number of tokens in %rax
#
# Definitions
# -----------
# The following are the definitions used to identify a single token
#
# ^^^^^^666^^^^^^           - 1st byte: 0, next 8 bytes: 0
# ^^^^^^666^^^^^^=          - 1st byte: 1, next 8 bytes: 0
# ^^^^^^666^^^^^^=M         - 1st byte: 2, next 8 bytes: 0
# ^^^^^^666^^^^^^=O         - 1st byte: 3, next 8 bytes: 0
# ~                         - 1st byte: 4, next 8 bytes: 0
# \\|//                     - 1st byte: 5, next 8 bytes: 0
# label                     - 1st byte: 6, next 8 bytes: address of string
# jump                      - 1st byte: 7, next 8 bytes: address of string
# conditional jump          - 1st byte: 8, next 8 bytes: address of string
# cell ident                - 1st byte: 9, next 8 bytes: address of string
# region ident              - 1st byte: 10, next 8 bytes: address of string
# primitive ident           - 1st byte: 11, next 8 bytes: address of string
#
# Token symbols are of the form LEXER_TOKEN_<token name> and they will alias their byte numbers
#
# Modus Operandi
# --------------
# In the following,
#   %r8 is the pointer to the array which will be returned
#   %r9 is the index of the input string
#   %r10 is the address of the current character in the input string
#   %r12 is address of the next place to put the token in the vector
#   %rbx is holding the current length of the token array
#
# 1. Initialize
#       %r9 to 0
#       %rbx to 0
#
# Repeat the following until %r9 == %rsi (length of buffer content)
# tokenize_loop:
# 9. Load the character in the buffer at index %r9 into %r10
# 11. Compare %r10 with ' '
# 12. If %r10 == ' ', return error whitespace
# 13. Compare %r10 with '~'
# 14. If %r10 == '~'
#       1. Move 4 into %r14
#       2. Move 0 into %r15
#       3. Call append_token
#       4. Goto repeat_tokenize_loop
# 15. Compare %r11 with '$'
# 16. If %r11 == '$'
#       1. Add 1 to %r9 to get the index of the next char in the string
#       2. Compare %r9 to %rsi, the length of the string
#       3. If %r9 == %rsi, return error expected primitive identifier or index
#       4. Load the address of the char at index %r9 into %r10
#       5. Move the value of the char specified by %r10 into %r11
#       6. Compare %r11 with primitive symbols and numbers
#       7. If no match, return error unrecognized token
#       8. Move 11 into %r14b
#       9. Move the address of the symbol / number into %r15
#       10. Call append_token
#       11. Goto repeat_tokenize_loop
# 17. Compare %r11 with '^'
# 18. If %r11 == '^'
#       1. Compare the next 5 chars with '^'
#       2. If any of them are not equal to '^', return error unrecognized token
#       3. Compare the next 3 chars with '6'
#       4. If any of them are not equal to '6', return error unrecognized token
#       5. Compare the next 6 tokens with '^'
#       6. If any of them are not equal to '^', return error unrecognized token
#       7. Increment %r9, to get the index of the next char in the string
#       8. Compare %r9 to %rsi, the string length, to know whether or not this is the end of input
#       9. If %r9 == %rsi
#           1. Move 0 into %r14, the number for ^^^^^^666^^^^^^
#           2. Move 0 into %r15b
#           3. Call append_to_vec
#           4. Move the pointer to the vector from %r8 into %rdi
#           5. Return with 0 in %rax
#       10. Load the address of the char at index %r9 into %r10
#       11. Move the char at address %r10 into %r11
#       12. Compare %r11 with '='
#       13. Do the previous end of input check
#       14. If this is the end of input
#           1. Move 1 into %r14, the number for ^^^^^^666^^^^^^=
#           2. Move 0 into %r15b
#           3. Call append_to_vec
#           4. Move the pointer to the vector from %r8 to %rdi
#           5. Return with 0 in %rax
#       15. Repeat the above comparisons for 'M' and 'O', which could come after '='
#       16. If none of 'M' or 'O' come after '=', append ^^^^^^666^^^^^^=
#       17. Goto repeat_tokenize_loop
# 19. Do the above comparisons and subsequent actions for the remaining token first characters
#
# repeat_tokenize_loop:
# 1. Add 1 to %r9
# 2. Compare %r9 with %rsi, the buffer length
# 3. If %r9 >= buffer length
#       1. Deallocate the string pointed to by %rsi
#       2. return the array
# 4. goto tokenize_loop
#
# append_token:
# 1. Load the address of position %rbx (previous array length) in the array into %r12
# 2. Move %r14b, %r15 into the location specified by %r12
# 3. Increase %rbx by 1

.section .data
.err_msg_tokenize_whitespace:
    .equ ERR_MSG_TOKENIZE_WHITESPACE_LEN, 42
    .asciz "Invalid whitespace at position n. Find n.\n"

.err_msg_tokenize_err_unrecognized_token:
    .equ ERR_MSG_TOKENIZE_ERR_UNRECOGNIZED_TOKEN_LEN, 42
    .asciz "Unrecognized token at position n. Find n.\n"

.token_tilde_repr:
    .equ TOKEN_TILDE_REPR_LEN, 9
    .asciz "tilde(~)\n"

.token_triple_six_repr:
    .equ TOKEN_TRIPLE_SIX_REPR_LEN, 28
    .asciz "triple six(^^^^^^666^^^^^^)\n"

.token_triple_six_eq_repr:
    .equ TOKEN_TRIPLE_SIX_EQ_REPR_LEN, 32
    .asciz "triple six eq(^^^^^^666^^^^^^=)\n"

.token_triple_six_eq_m_repr:
    .equ TOKEN_TRIPLE_SIX_EQ_M_REPR_LEN, 33
    .asciz "triple six eq(^^^^^^666^^^^^^=M)\n"

.token_triple_six_eq_o_repr:
    .equ TOKEN_TRIPLE_SIX_EQ_O_REPR_LEN, 33
    .asciz "triple six eq(^^^^^^666^^^^^^=O)\n"

.token_drill_repr:
    .equ TOKEN_DRILL_REPR_LEN, 13
    .asciz "drill(\\\\|//)\n"

# The size of a token in bytes
# Used by the allocator to determine how
# much space should be reserved for the token array
.equ TOKEN_SIZE, 9

# Some ascii
.equ EOF, 4
.equ BACKSLASH, 92
.equ FORWARD_SLASH, 47
.equ PIPE, 124

# Token numbers
.equ TRIPLE_SIX, 0
.equ TRIPLE_SIX_EQ, 1
.equ TRIPLE_SIX_EQ_M, 2
.equ TRIPLE_SIX_EQ_O, 3
.equ TILDE, 4
.equ DRILL, 5
.equ LABEL, 6
.equ JUMP, 7
.equ CJUMP, 8
.equ CELL_IDENT, 9
.equ REGION_IDENT, 10
.equ PRIMITIVE_IDENT, 11

.section .text
lexer_tokenize:
    movq $0, %r9
    movq $0, %rbx
    xor %r10, %r10
    movq $0, %r14
    movq $0, %r15
    jmp lexer_tokenize_loop

lexer_tokenize_loop:
    movb (%rdi, %r9, 1), %r10b
    cmp $' ', %r10b
    je lexer_tokenize_err_whitespace
    cmp $'\n', %r10b
    je lexer_tokenize_err_whitespace
    cmp $'~', %r10b
    je lexer_tokenize_leach
    cmp $'^', %r10b
    je lexer_tokenize_triple_six
    cmp $BACKSLASH, %r10b
    je lexer_tokenize_drill
    cmp $'l', %r10b
    je lexer_tokenize_label
    cmp $EOF, %r10b
    je lexer_tokenize_loop_end
    jmp lexer_tokenize_err_unrecognized_token

lexer_tokenize_leach:
    movq $TILDE, %r14
    movq $0, %r15
    call lexer_append_token
    jmp lexer_repeat_tokenize_loop

lexer_tokenize_triple_six:
    movq $0, %r11           # Starting from 0
    movq $5, %r12           # Stopping at 5, meaning check for '^' %r12 - %r11 times
    call lexer_tokenize_triple_six_carets_loop
    movq $0, %r11           # Same as in previous loop
    movq $3, %r12
    call lexer_tokenize_triple_six_middle_sixes_loop
    movq $0, %r11           # Same as in previous loop
    movq $6, %r12
    call lexer_tokenize_triple_six_carets_loop
    movq %r9, %r11
    incq %r11
    je lexer_append_triple_six_and_end
    movb (%rdi, %r11, 1), %r10b
    cmp $'=', %r10b
    je lexer_tokenize_triple_six_eq
    movq $TRIPLE_SIX, %r14
    movq $0, %r15
    call lexer_append_token
    jmp lexer_repeat_tokenize_loop

lexer_tokenize_triple_six_eq:
    incq %r9
    incq %r11
    cmp %r11, %rsi
    je lexer_append_triple_six_eq_and_end
    movb (%rdi, %r11, 1), %r10b
    cmp $'M', %r10b
    je lexer_tokenize_triple_six_eq_m
    cmp $'O', %r10b
    je lexer_tokenize_triple_six_eq_o
    movb $TRIPLE_SIX_EQ, %r14b
    movq $0, %r15
    call lexer_append_token
    jmp lexer_repeat_tokenize_loop

lexer_tokenize_triple_six_eq_m:
    incq %r9
    movb $TRIPLE_SIX_EQ_M, %r14b
    movq $0, %r15
    call lexer_append_token
    jmp lexer_repeat_tokenize_loop

lexer_tokenize_triple_six_eq_o:
    incq %r9
    movb $TRIPLE_SIX_EQ_O, %r14b
    movq $0, %r15
    call lexer_append_token
    jmp lexer_repeat_tokenize_loop

lexer_append_triple_six_and_end:
    movb $TRIPLE_SIX, %r14b
    movq $0, %r15
    call lexer_append_token
    jmp lexer_tokenize_loop_end

lexer_append_triple_six_eq_and_end:
    movb $TRIPLE_SIX_EQ, %r14b
    movq $0, %r15
    call lexer_append_token
    jmp lexer_tokenize_loop_end

lexer_tokenize_triple_six_carets_loop:
    cmp %r11, %r12
    je lexer_tokenize_triple_six_carets_loop_end
    incq %r9
    cmp %r9, %rsi
    je lexer_tokenize_err_unrecognized_token
    movb (%rdi, %r9, 1), %r10b
    cmp $' ', %r10b
    je lexer_tokenize_err_whitespace
    cmp $'^', %r10b
    jne lexer_tokenize_err_unrecognized_token
    incq %r11
    jmp lexer_tokenize_triple_six_carets_loop

lexer_tokenize_triple_six_carets_loop_end:
    ret

lexer_tokenize_triple_six_middle_sixes_loop:
    cmp %r11, %r12
    je lexer_tokenize_triple_six_middle_sixes_loop_end
    incq %r9
    cmp %r9, %rsi
    je lexer_tokenize_err_unrecognized_token
    movb (%rdi, %r9, 1), %r10b
    cmp $' ', %r10b
    je lexer_tokenize_err_whitespace
    cmp $'6', %r10b
    jne lexer_tokenize_err_unrecognized_token
    incq %r11
    jmp lexer_tokenize_triple_six_middle_sixes_loop

lexer_tokenize_triple_six_middle_sixes_loop_end:
    ret

lexer_tokenize_drill:
    call lexer_tokenize_drill_check_for_errors
    cmp $BACKSLASH, %r10b
    jne lexer_tokenize_err_unrecognized_token
    call lexer_tokenize_drill_check_for_errors
    cmp $PIPE, %r10b
    jne lexer_tokenize_err_unrecognized_token
    call lexer_tokenize_drill_check_for_errors
    cmp $FORWARD_SLASH, %r10b
    jne lexer_tokenize_err_unrecognized_token
    call lexer_tokenize_drill_check_for_errors
    cmp $FORWARD_SLASH, %r10b
    jne lexer_tokenize_err_unrecognized_token
    movb $DRILL, %r14b
    movq $0, %r15
    call lexer_append_token
    jmp lexer_repeat_tokenize_loop

lexer_tokenize_drill_check_for_errors:
    incq %r9
    cmp %r9, %rsi
    je lexer_tokenize_err_unrecognized_token

    movb (%rdi, %r9, 1), %r10b
    cmp $' ', %r10b
    je lexer_tokenize_err_whitespace
    ret
    
lexer_repeat_tokenize_loop:
    incq %r9
    cmp %r9, %rsi
    je lexer_tokenize_loop_end
    jmp lexer_tokenize_loop

lexer_tokenize_loop_end:
    call lexer_print_tokens
    movq %rbx, %rax             # The number of tokens
    ret

lexer_tokenize_label:
    

lexer_append_token:
    movq %rbx, %r12
    imul $TOKEN_SIZE, %r12
    addq %rdx, %r12             # Calculating the location of the current index
    movb %r14b, (%r12)
    incq %r12
    movq %r15, (%r12)
    movq $0, %r14
    movq $0, %r15
    incq %rbx
    ret

lexer_tokenize_err_whitespace:
    leaq .err_msg_tokenize_whitespace(%rip), %rdi
    movq $ERR_MSG_TOKENIZE_WHITESPACE_LEN, %rsi
    movq $-1, %rax
    ret

lexer_tokenize_err_unrecognized_token:
    leaq .err_msg_tokenize_err_unrecognized_token(%rip), %rdi
    movq $ERR_MSG_TOKENIZE_ERR_UNRECOGNIZED_TOKEN_LEN, %rsi
    movq $-1, %rax
    ret

# Role
# ----
# Prints tokens for debugging
lexer_print_tokens:
    pushq %r8           # Save %r8
    pushq %r9           # Save %r9
    pushq %rdi
    pushq %rsi
    movq $0, %r8        # Initialize token array index
    movq $0, %r9
    jmp lexer_print_tokens_loop

lexer_print_tokens_loop:
    cmp %r8, %rbx
    je lexer_print_tokens_loop_end
    movq %r8, %r12
    imul $TOKEN_SIZE, %r12
    addq %rdx, %r12             # Calculating the location of the current index
    movb (%r12), %r9b
    cmp $TILDE, %r9b
    je lexer_print_token_tilde
    cmp $TRIPLE_SIX, %r9b
    je lexer_print_token_triple_six
    cmp $TRIPLE_SIX_EQ, %r9b
    je lexer_print_token_triple_six_eq
    cmp $TRIPLE_SIX_EQ_O, %r9b
    je lexer_print_token_triple_six_eq_o
    cmp $TRIPLE_SIX_EQ_M, %r9b
    je lexer_print_token_triple_six_eq_m
    cmp $DRILL, %r9b
    je lexer_print_token_drill

lexer_print_token_tilde:
    leaq .token_tilde_repr(%rip), %rdi
    movq $TOKEN_TILDE_REPR_LEN, %rsi
    jmp lexer_print_token

lexer_print_token_triple_six:
    leaq .token_triple_six_repr(%rip), %rdi
    movq $TOKEN_TRIPLE_SIX_REPR_LEN, %rsi
    jmp lexer_print_token

lexer_print_token_triple_six_eq:
    leaq .token_triple_six_eq_repr(%rip), %rdi
    movq $TOKEN_TRIPLE_SIX_EQ_REPR_LEN, %rsi
    jmp lexer_print_token

lexer_print_token_triple_six_eq_o:
    leaq .token_triple_six_eq_o_repr(%rip), %rdi
    movq $TOKEN_TRIPLE_SIX_EQ_O_REPR_LEN, %rsi
    jmp lexer_print_token

lexer_print_token_triple_six_eq_m:
    leaq .token_triple_six_eq_m_repr(%rip), %rdi
    movq $TOKEN_TRIPLE_SIX_EQ_M_REPR_LEN, %rsi
    jmp lexer_print_token

lexer_print_token_drill:
    leaq .token_drill_repr(%rip), %rdi
    movq $TOKEN_DRILL_REPR_LEN, %rsi
    jmp lexer_print_token
    
lexer_print_token:
    pushq %r8
    pushq %rdi
    pushq %rdx
    call utils_print
    popq %rdx
    popq %rdi
    popq %r8
    incq %r8
    jmp lexer_print_tokens_loop

lexer_print_tokens_loop_end:
    popq %rsi
    popq %rdi
    popq %r9
    popq %r8
    ret