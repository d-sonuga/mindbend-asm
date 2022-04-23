# Role
# ----
# Turn raw input into a vector of tokens
#
# Expected
# --------
# 1. A pointer to the raw input is stored in %rdi
# 2. The length of the buffer content is stored in %rsi
#
# Result
# ------
# 1. In the case of an error, -1 in %rax, a pointer to the error string in %rdi, the string length in %rsi
# 2. In the case of a success, 0 in %rax, a pointer to a vector of numbers in %rdi
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
#   %r8 is the pointer to the vector which will be returned
#   %r9 is the index of the input string
#   %r10 is the address of the current character in the input string
#   %r11 is the current character being considered in the input string
#   %r12 is address of the next place to put the token in the vector
#
# 1. Save %rdi and %rsi
# 2. Move the size of a single token (9) into %rdi, leave the length of the buffer in %rsi
# 3. Call utils_vec_init
# 4. Compare %rax with 0
# 5. If %rax is lesser than 0, utils_vec_init returned with an error, return the error
# 6. Else, move %rdi into %r8
# 7. Restore the previous %rdi and %rsi values
# 8. Initialize %r9 to 0
#
# Repeat the following until %r9 == %rsi (length of buffer content)
# tokenize_loop:
# 9. Load the address of string at index %r9 into %r10
# 10. Move the value of the character at address specified by %r10 into %r11
# 11. Compare %r11 with ' '
# 12. If %r11 == ' ', return error whitespace
# 13. Compare %r11 with '~'
# 14. If %r11 == '~'
#       1. Move 4 into %r15
#       2. Move 0 into %r14
#       3. Call append_to_vec
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
#       8. Move 11 into %r15b
#       9. Move the address of the symbol / number into %r14
#       10. Call append_to_vec
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
#           1. Move 0 into %r15, the number for ^^^^^^666^^^^^^
#           2. Move 0 into %r14b
#           3. Call append_to_vec
#           4. Move the pointer to the vector from %r8 into %rdi
#           5. Return with 0 in %rax
#       10. Load the address of the char at index %r9 into %r10
#       11. Move the char at address %r10 into %r11
#       12. Compare %r11 with '='
#       13. Do the previous end of input check
#       14. If this is the end of input
#           1. Move 1 into %r15, the number for ^^^^^^666^^^^^^=
#           2. Move 0 into %r14b
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
#       2. return the vector
# 4. Load the address of the char at index %r9 into %r10
# 5. Move the value of the char specified by %r10 into %r11
# 6. goto tokenize_loop
#
# append_to_vec:
# 1. Load the address of the next position in the vector into %r12
# 2. Move %r15b, %r14 into the location specified by %r12
# 3. Increase the vector's length field by 1

# The size of a token in bytes
# Used by the allocator to determine how
# much space should be reserved for the token array
.equ TOKEN_SIZE, 9