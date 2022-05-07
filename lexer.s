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

.err_msg_tokenize_empty_label:
    .equ ERR_MSG_TOKENIZE_EMPTY_LABEL_LEN, 34
    .asciz "Empty label or jump at n. Find n.\n"

.err_msg_tokenize_malformed_label:
    .equ ERR_MSG_TOKENIZE_MALFORMED_LABEL_LEN, 38
    .asciz "Malformed label or jump at n. Find n.\n"

.err_msg_tokenize_unrecognized_region_ident:
    .equ ERR_MSG_TOKENIZE_UNRECOGNIZED_REGION_IDENT_LEN, 40
    .asciz "Unrecognized region ident at n. Find n.\n"

.err_msg_tokenize_unrecognized_primitive_ident:
    .equ ERR_MSG_TOKENIZE_UNRECOGNIZED_PRIMITIVE_IDENT_LEN, 43
    .asciz "Unrecognized primitive ident at n. Find n.\n"

.err_msg_org_expr_must_end_in_death:
    .equ ERR_MSG_ORG_EXPR_MUST_END_IN_DEATH_LEN, 73
    .asciz "Every mindbend program must end in the death of the Organism Expression.\n"

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

.token_label_repr_start:
    .equ TOKEN_LABEL_REPR_START_LEN, 6
    .asciz "label("

.token_label_repr_end:
    .equ TOKEN_LABEL_REPR_END_LEN, 2
    .asciz ")\n"

.token_jump_repr_start:
    .equ TOKEN_JUMP_REPR_START_LEN, 5
    .asciz "jump("

.token_jump_repr_end:
    .equ TOKEN_JUMP_REPR_END_LEN, 2
    .asciz ")\n"

.token_cjump_repr_start:
    .equ TOKEN_CJUMP_REPR_START_LEN, 6
    .asciz "ijump("

.token_cjump_repr_end:
    .equ TOKEN_CJUMP_REPR_END_LEN, 2
    .asciz ")\n"

.token_cell_ident_repr_start:
    .equ TOKEN_CELL_IDENT_REPR_START_LEN, 11
    .asciz "cell ident("

.token_cell_ident_repr_end:
    .equ TOKEN_CELL_IDENT_REPR_END_LEN, 2
    .asciz ")\n"

.token_region_ident_repr_start:
    .equ TOKEN_REGION_IDENT_REPR_START_LEN, 13
    .asciz "region ident("

.token_region_ident_repr_end:
    .equ TOKEN_REGION_IDENT_REPR_END_LEN, 2
    .asciz ")\n"

.token_primitive_ident_repr_start:
    .equ TOKEN_PRIMITIVE_IDENT_REPR_START_LEN, 16
    .asciz "primitive ident("

.token_primitive_ident_repr_end:
    .equ TOKEN_PRIMITIVE_IDENT_REPR_END_LEN, 2
    .asciz ")\n"

.print_tokens_header:
    .equ PRINT_TOKENS_HEADER_LEN, 8
    .asciz "Tokens:\n"


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

.equ TOKEN_STRING_ADDR_OFFSET, 1

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
    cmp $'j', %r10b
    je lexer_tokenize_jump
    cmp $'i', %r10b
    je lexer_tokenize_conditional_jump
    cmp $'-', %r10b
    je lexer_tokenize_region_ident
    cmp $'$', %r10b
    je lexer_tokenize_primitive_ident
    cmp $'0', %r10b
    je lexer_tokenize_cell_ident
    cmp $'1', %r10b
    je lexer_tokenize_cell_ident
    cmp $'2', %r10b
    je lexer_tokenize_cell_ident
    cmp $'3', %r10b
    je lexer_tokenize_cell_ident
    cmp $'4', %r10b
    je lexer_tokenize_cell_ident
    cmp $'5', %r10b
    je lexer_tokenize_cell_ident
    cmp $'6', %r10b
    je lexer_tokenize_cell_ident
    cmp $'7', %r10b
    je lexer_tokenize_cell_ident
    cmp $'8', %r10b
    je lexer_tokenize_cell_ident
    cmp $'9', %r10b
    je lexer_tokenize_cell_ident
    cmp $'A', %r10b
    je lexer_tokenize_cell_ident
    cmp $'B', %r10b
    je lexer_tokenize_cell_ident
    cmp $'C', %r10b
    je lexer_tokenize_cell_ident
    cmp $'D', %r10b
    je lexer_tokenize_cell_ident
    cmp $'E', %r10b
    je lexer_tokenize_cell_ident
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
    movq $0, %rax           # In case there are any errors
    call lexer_tokenize_triple_six_carets_loop
    cmp $0, %rax
    jl lexer_return         # If error, return it
    movq $0, %r11           # Same as in previous loop
    movq $3, %r12
    call lexer_tokenize_triple_six_middle_sixes_loop
    cmp $0, %rax
    jl lexer_return         # If error, return it
    movq $0, %r11           # Same as in previous loop
    movq $6, %r12
    call lexer_tokenize_triple_six_carets_loop
    cmp $0, %rax
    jl lexer_return         # If error, return it
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
    movq %r9, %r15                          # Index of the next character
    incq %r15
    cmp %r15, %rsi
    jne lexer_repeat_tokenize_loop          # Ignore all ^^^^^^666^^^^^^=O except the last one
    movb $TRIPLE_SIX_EQ_O, %r14b
    movq $0, %r15
    call lexer_append_token
    jmp lexer_tokenize_loop_end

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
    cmp $'\n', %r10b
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
    cmp $'\n', %r10b
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
    cmp $'\n', %r10b
    je lexer_tokenize_err_whitespace
    ret
    
lexer_repeat_tokenize_loop:
    incq %r9
    cmp %r9, %rsi                   # Is the current input string index equal to the length of the input string?
    je lexer_tokenize_loop_end
    jmp lexer_tokenize_loop

lexer_tokenize_loop_end:
    movq %rbx, %r9
    decq %r9                                    # Index of the last token
    imul $TOKEN_SIZE, %r9                       
    addq %rdx, %r9                              # Address of the last token
    movb (%r9), %r9b
    cmp $TRIPLE_SIX_EQ_O, %r9b                  # Last token should be ^^^^^^666^^^^^^=O
    jne lexer_err_org_expr_must_end_in_death
    call lexer_print_tokens
    movq %rbx, %rax                             # The number of tokens
    decq %rax                                   # The ^^^^^^666^^^^^^=O should be ignored
    ret

lexer_tokenize_label:
    movq $0, %rax
    call lexer_tokenize_lji_next_char
    cmp $0, %rax
    jl lexer_return
    cmp $'a', %r10b
    jne lexer_tokenize_err_unrecognized_token
    call lexer_tokenize_lji_next_char
    cmp $0, %rax
    jl lexer_return
    cmp $'b', %r10b
    jne lexer_tokenize_err_unrecognized_token
    cmp $0, %rax
    jl lexer_return
    call lexer_tokenize_lji_next_char
    cmp $0, %rax
    jl lexer_return
    cmp $'e', %r10b
    jne lexer_tokenize_err_unrecognized_token
    call lexer_tokenize_lji_next_char
    cmp $0, %rax
    jl lexer_return
    cmp $'l', %r10b
    jne lexer_tokenize_err_unrecognized_token
    call lexer_tokenize_lji_next_char
    cmp $0, %rax
    jl lexer_return
    cmp $':', %r10b
    jne lexer_tokenize_err_unrecognized_token
    xor %r12, %r12
    movq $LABEL, %r12
    jmp lexer_tokenize_lji_name

lexer_tokenize_jump:
    movq $0, %rax
    call lexer_tokenize_lji_next_char
    cmp $0, %rax
    jl lexer_return
    cmp $'m', %r10b
    jne lexer_tokenize_err_unrecognized_token
    cmp $0, %rax
    jl lexer_return
    call lexer_tokenize_lji_next_char
    cmp $0, %rax
    jl lexer_return
    cmp $'p', %r10b
    jne lexer_tokenize_err_unrecognized_token
    call lexer_tokenize_lji_next_char
    cmp $0, %rax
    jl lexer_return
    cmp $':', %r10b
    jne lexer_tokenize_err_unrecognized_token
    xor %r12, %r12
    movq $JUMP, %r12
    jmp lexer_tokenize_lji_name

lexer_tokenize_conditional_jump:
    movq $0, %rax
    call lexer_tokenize_lji_next_char
    cmp $0, %rax
    jl lexer_return
    cmp $'j', %r10b
    jne lexer_tokenize_err_unrecognized_token
    call lexer_tokenize_lji_next_char
    cmp $0, %rax
    jl lexer_return
    cmp $'u', %r10b
    jne lexer_tokenize_err_unrecognized_token
    call lexer_tokenize_lji_next_char
    cmp $0, %rax
    jl lexer_return
    cmp $'m', %r10b
    jne lexer_tokenize_err_unrecognized_token
    cmp $0, %rax
    jl lexer_return
    call lexer_tokenize_lji_next_char
    cmp $0, %rax
    jl lexer_return
    cmp $'p', %r10b
    jne lexer_tokenize_err_unrecognized_token
    call lexer_tokenize_lji_next_char
    cmp $0, %rax
    jl lexer_return
    cmp $':', %r10b
    jne lexer_tokenize_err_unrecognized_token
    xor %r12, %r12
    movq $CJUMP, %r12
    jmp lexer_tokenize_lji_name

lexer_tokenize_cell_ident:
    pushq %rdi
    movq $2, %rdi                       # Space for the single letter cell ident and a null byte
    call utils_alloc
    popq %rdi
    cmp $0, %rax
    jl lexer_return
    movb %r10b, (%rax)                   # Store the cell ident
    movb $0, 1(%rax)                    # Null terminate it
    movb $CELL_IDENT, %r14b
    movq %rax, %r15
    call lexer_append_token
    jmp lexer_repeat_tokenize_loop

lexer_tokenize_region_ident:
    incq %r9
    cmp %r9, %rsi
    je lexer_tokenize_err_unrecognized_token
    movb (%rdi, %r9, 1), %r10b
    cmp $' ', %r10b
    je lexer_tokenize_err_whitespace
    cmp $'\n', %r10b
    je lexer_tokenize_err_whitespace
    cmp $'>', %r10b
    jne lexer_tokenize_err_unrecognized_token
    incq %r9
    cmp %r9, %rsi
    je lexer_tokenize_err_unrecognized_token
    movb (%rdi, %r9, 1), %r10b
    cmp $' ', %r10b
    je lexer_tokenize_err_whitespace 
    cmp $'\n', %r10b
    je lexer_tokenize_err_whitespace
    cmp $'C', %r10b
    je lexer_tokenize_region_ident_name
    cmp $'L', %r10b
    je lexer_tokenize_region_ident_name
    jne lexer_tokenize_err_unrecognized_region_ident

lexer_tokenize_region_ident_name:
    pushq %rdi
    movq $2, %rdi
    call utils_alloc
    movb %r10b, (%rax)          # Save the region identifier name in the location allocated for it
    movb $0, 1(%rax)            # Null terminate it
    movb $REGION_IDENT, %r14b
    movq %rax, %r15
    call lexer_append_token
    popq %rdi
    jmp lexer_repeat_tokenize_loop

lexer_tokenize_primitive_ident:
    incq %r9
    cmp %r9, %rsi
    je lexer_tokenize_err_unrecognized_primitive_ident
    movb (%rdi, %r9, 1), %r10b
    cmp $' ', %r10b
    je lexer_tokenize_err_whitespace
    cmp $'\n', %r10b
    je lexer_tokenize_err_whitespace
    movq $1, %r12                           # The default length of the identifier
    cmp $'!', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'@', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'#', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'+', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'%', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'`', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'&', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'*', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'(', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $')', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'{', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'}', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'0', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'1', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'2', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'3', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'4', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'5', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'6', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'7', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'8', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'9', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'A', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'B', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'C', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'D', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'E', %r10b
    je lexer_tokenize_primitive_ident_name
    cmp $'>', %r10b
    je lexer_tokenize_primitive_ident_great_less_name
    cmp $'<', %r10b
    je lexer_tokenize_primitive_ident_less_great_name
    jmp lexer_tokenize_err_unrecognized_primitive_ident

lexer_tokenize_primitive_ident_name:
    pushq %rdi
    movq $2, %rdi
    call utils_alloc
    cmp $0, %rax
    jl lexer_return
    movb %r10b, (%rax)
    movb $0, 1(%rax)
    movb $PRIMITIVE_IDENT, %r14b
    movq %rax, %r15
    call lexer_append_token
    popq %rdi
    jmp lexer_repeat_tokenize_loop

lexer_tokenize_primitive_ident_great_less_name:
    pushq $'>'
    incq %r9
    cmp %r9, %rsi
    je lexer_tokenize_err_unrecognized_primitive_ident
    movb (%rdi, %r9, 1), %r10b
    cmp $' ', %r10b
    je lexer_tokenize_err_whitespace
    cmp $'\n', %r10b
    je lexer_tokenize_err_whitespace
    cmp $'<', %r10b
    jne lexer_tokenize_err_unrecognized_primitive_ident
    pushq $'<'
    jmp lexer_tokenize_primitive_ident_append_double_len_primitive

lexer_tokenize_primitive_ident_less_great_name:
    pushq $'<'
    incq %r9
    cmp %r9, %rsi
    je lexer_tokenize_err_unrecognized_primitive_ident
    movb (%rdi, %r9, 1), %r10b
    cmp $' ', %r10b
    je lexer_tokenize_err_whitespace
    cmp $'\n', %r10b
    je lexer_tokenize_err_whitespace
    cmp $'>', %r10b
    pushq $'>'
    jne lexer_tokenize_err_unrecognized_primitive_ident
    jmp lexer_tokenize_primitive_ident_append_double_len_primitive

lexer_tokenize_primitive_ident_append_double_len_primitive:
    pushq %rdi
    movq $3, %rdi
    call utils_alloc
    cmp $0, %rax
    jl lexer_return
    popq %rdi
    popq %r12                       # The second letter in the identifier
    popq %r10                       # The first letter in the identifier
    movb %r10b, (%rax)
    movb %r12b, 1(%rax)
    movb $0, 2(%rax)
    movb $PRIMITIVE_IDENT, %r14b
    movq %rax, %r15
    call lexer_append_token
    jmp lexer_repeat_tokenize_loop

lexer_tokenize_lji_next_char:
    incq %r9
    cmp %r9, %rsi
    je lexer_tokenize_err_unrecognized_token
    movb (%rdi, %r9, 1), %r10b
    cmp $' ', %r10b
    je lexer_tokenize_err_whitespace
    cmp $'\n', %r10b
    je lexer_tokenize_err_whitespace
    cmp $EOF, %r10b
    je lexer_tokenize_err_malformed_label
    ret

lexer_tokenize_lji_name:
    incq %r9
    cmp %r9, %rsi
    je lexer_tokenize_err_unrecognized_token
    movb (%rdi, %r9, 1), %r10b
    cmp $':', %r10b                                 # Ought to be the beginning of the label name
    je lexer_tokenize_err_empty_label
    movq %r9, %r13                                  # Initializing the string index to it's index in the input
    movq $0, %rax                                   # In case the next command returns an error
    call lexer_calc_name_len_loop                   # Calculate name length and stores it in %r13
    cmp $0, %rax
    jl lexer_return                                 # If error, return
    call lexer_store_name                           # Allocate space and store the name in it. Address in %rax
    movb %r12b, %r14b
    movq %rax, %r15
    call lexer_append_token
    jmp lexer_repeat_tokenize_loop

lexer_calc_name_len_loop:
    cmp %rsi, %r13
    je lexer_tokenize_err_malformed_label
    movb (%rdi, %r13, 1), %r10b
    cmp $':', %r10b
    je lexer_calc_name_len_loop_end
    cmp $' ', %r10b
    je lexer_tokenize_err_whitespace
    cmp $'\n', %r10b
    je lexer_tokenize_err_whitespace
    cmp $EOF, %r10b
    je lexer_tokenize_err_malformed_label
    incq %r13
    jmp lexer_calc_name_len_loop

lexer_calc_name_len_loop_end:
    subq %r9, %r13          # Last index + 1 - first index = length
    ret

lexer_store_name:
    pushq %rdi          # Save the input string's address
    pushq %r13          # Save the number of bytes the label name has
    movq %r13, %rdi     # The number of bytes the label name has
    incq %rdi           # Allocating space for n + 1, to accomodate a terminating null byte
    call utils_alloc    # %rax will contain the address of the string to place the name in
    cmp $0, %rax
    jl lexer_return     # If error, return the error
    popq %r13           # Restore the byte number
    popq %rdi           # Restore the input string's address
    movq $0, %r8        # Starting index
    jmp lexer_copy_name_into_string_loop

lexer_copy_name_into_string_loop:
    cmp %r8, %r13               # Is the current index equal to the number of bytes?
    je lexer_copy_name_into_string_loop_end
    movq %r8, %r11
    addq %r9, %r11              #  Base index of label name in program (%r9) + current index of label name (%r11) = Index of letter in the whole input string
    movb (%rdi, %r11, 1), %r10b
    movb %r10b, (%rax, %r8, 1)
    incq %r8
    jmp lexer_copy_name_into_string_loop

lexer_copy_name_into_string_loop_end:
    addq %r8, %r9                   # Update %r9 to point to the ':' at the end of the label name
    movb $0,  %r10b
    movb %r10b, (%rax, %r8, 1)      # Null terminating the string
    ret

lexer_return:
    ret

lexer_append_token:
    pushq %r12
    movq %rbx, %r12             # Current length of the token array
    imul $TOKEN_SIZE, %r12      # The amount of space the token array is currently taking up, in bytes
    addq %rdx, %r12             # Address of token buffer (%rdx) + Token array space = location to append token
    movb %r14b, (%r12)
    incq %r12
    movq %r15, (%r12)
    movq $0, %r14
    movq $0, %r15
    incq %rbx
    popq %r12
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

lexer_tokenize_err_empty_label:
    leaq .err_msg_tokenize_empty_label(%rip), %rdi
    movq $ERR_MSG_TOKENIZE_EMPTY_LABEL_LEN, %rsi
    movq $-1, %rax
    ret

lexer_tokenize_err_malformed_label:
    leaq .err_msg_tokenize_malformed_label(%rip), %rdi
    movq $ERR_MSG_TOKENIZE_MALFORMED_LABEL_LEN, %rsi
    movq $-1, %rax
    ret

lexer_tokenize_err_unrecognized_region_ident:
    leaq .err_msg_tokenize_unrecognized_region_ident(%rip), %rdi
    movq $ERR_MSG_TOKENIZE_UNRECOGNIZED_REGION_IDENT_LEN, %rsi
    movq $-1, %rax
    ret

lexer_tokenize_err_unrecognized_primitive_ident:
    leaq .err_msg_tokenize_unrecognized_primitive_ident(%rip), %rdi
    movq $ERR_MSG_TOKENIZE_UNRECOGNIZED_PRIMITIVE_IDENT_LEN, %rsi
    movq $-1, %rax
    ret

lexer_err_org_expr_must_end_in_death:
    leaq .err_msg_org_expr_must_end_in_death(%rip), %rdi
    movq $ERR_MSG_ORG_EXPR_MUST_END_IN_DEATH_LEN, %rsi
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
    pushq %r10
    leaq .print_tokens_header(%rip), %rdi
    movq $PRINT_TOKENS_HEADER_LEN, %rsi
    call utils_print
    movq $0, %r8        # Initialize token array index
    movq $0, %r9
    jmp lexer_print_tokens_loop

lexer_print_tokens_loop:
    cmp %r8, %rbx
    je lexer_print_tokens_loop_end
    movq %r8, %r12
    imul $TOKEN_SIZE, %r12
    addq %rdx, %r12             # Calculating the location of the current index
    movb (%r12), %r9b           # The token field
    incq %r12
    movq (%r12), %r10          # The associated string address field, if any
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
    cmp $LABEL, %r9b
    je lexer_print_token_label
    cmp $JUMP, %r9b
    je lexer_print_token_jump
    cmp $CJUMP, %r9b
    je lexer_print_token_cjump
    cmp $CELL_IDENT, %r9b
    je lexer_print_token_cell_ident
    cmp $REGION_IDENT, %r9b
    je lexer_print_token_region_ident
    cmp $PRIMITIVE_IDENT, %r9b
    je lexer_print_token_primitive_ident

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

lexer_print_token_label:
    leaq .token_label_repr_start(%rip), %rdi
    movq $TOKEN_LABEL_REPR_START_LEN, %rsi
    pushq %r8
    pushq %rdi
    pushq %rdx
    call utils_print
    movq %r10, %rdi         # Address of the label
    pushq %r8
    pushq %r9
    call utils_strlen
    popq %r8
    popq %r9
    movq %rax, %rsi         # Length of the label
    call utils_print
    popq %rdx
    popq %rdi
    popq %r8
    leaq .token_label_repr_end(%rip), %rdi
    movq $TOKEN_LABEL_REPR_END_LEN, %rsi
    jmp lexer_print_token
    
lexer_print_token_jump:
    leaq .token_jump_repr_start(%rip), %rdi
    movq $TOKEN_JUMP_REPR_START_LEN, %rsi
    pushq %r8
    pushq %rdi
    pushq %rdx
    call utils_print
    movq %r10, %rdi         # Address of the identifier
    pushq %r8
    pushq %r9
    call utils_strlen
    popq %r8
    popq %r9
    movq %rax, %rsi         # Length of the identifier
    call utils_print
    popq %rdx
    popq %rdi
    popq %r8
    leaq .token_jump_repr_end(%rip), %rdi
    movq $TOKEN_JUMP_REPR_END_LEN, %rsi
    jmp lexer_print_token

lexer_print_token_cjump:
    leaq .token_cjump_repr_start(%rip), %rdi
    movq $TOKEN_CJUMP_REPR_START_LEN, %rsi
    pushq %r8
    pushq %rdi
    pushq %rdx
    call utils_print
    movq %r10, %rdi         # Address of the identifier
    pushq %r8
    pushq %r9
    call utils_strlen
    popq %r8
    popq %r9
    movq %rax, %rsi         # Length of the identifier
    call utils_print
    popq %rdx
    popq %rdi
    popq %r8
    leaq .token_cjump_repr_end(%rip), %rdi
    movq $TOKEN_CJUMP_REPR_END_LEN, %rsi
    jmp lexer_print_token

lexer_print_token_cell_ident:
    leaq .token_cell_ident_repr_start(%rip), %rdi
    movq $TOKEN_CELL_IDENT_REPR_START_LEN, %rsi
    pushq %r8
    pushq %rdi
    pushq %rdx
    call utils_print
    movq %r10, %rdi         # Address of the identifier
    pushq %r8
    pushq %r9
    call utils_strlen
    popq %r8
    popq %r9
    movq %rax, %rsi         # Length of the identifier
    call utils_print
    popq %rdx
    popq %rdi
    popq %r8
    leaq .token_cell_ident_repr_end(%rip), %rdi
    movq $TOKEN_CELL_IDENT_REPR_END_LEN, %rsi
    jmp lexer_print_token

lexer_print_token_region_ident:
    leaq .token_region_ident_repr_start(%rip), %rdi
    movq $TOKEN_REGION_IDENT_REPR_START_LEN, %rsi
    pushq %r8
    pushq %rdi
    pushq %rdx
    call utils_print
    movq %r10, %rdi         # Address of the identifier
    pushq %r8
    pushq %r9
    call utils_strlen
    popq %r8
    popq %r9
    movq %rax, %rsi         # Length of the identifier
    call utils_print
    popq %rdx
    popq %rdi
    popq %r8
    leaq .token_region_ident_repr_end(%rip), %rdi
    movq $TOKEN_REGION_IDENT_REPR_END_LEN, %rsi
    jmp lexer_print_token

lexer_print_token_primitive_ident:
    leaq .token_primitive_ident_repr_start(%rip), %rdi
    movq $TOKEN_PRIMITIVE_IDENT_REPR_START_LEN, %rsi
    pushq %r8
    pushq %rdi
    pushq %rdx
    call utils_print
    movq %r10, %rdi         # Address of the identifier
    pushq %r8
    pushq %r9
    call utils_strlen
    popq %r8
    popq %r9
    movq %rax, %rsi         # Length of the identifier
    call utils_print
    popq %rdx
    popq %rdi
    popq %r8
    leaq .token_primitive_ident_repr_end(%rip), %rdi
    movq $TOKEN_PRIMITIVE_IDENT_REPR_END_LEN, %rsi
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
    popq %r10
    popq %rsi
    popq %rdi
    popq %r9
    popq %r8
    call utils_print_newline
    ret
