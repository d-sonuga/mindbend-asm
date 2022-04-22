# Role
# ----
# Turn a vector of tokens into an expression structure
#
# Expected
# --------
# 1. The pointer to the vector of tokens is in %rdi
# 2. The pointer to a vector to be used for encountered labels in %rsi
# 3. The pointer to a vector to be used for encountered jumps in %rdx
#
# Result
# ------
# 1. In the case of an error, -1 in %rax, a pointer to the error string in %rdi, the string length in %rsi
# 2. In the case of a success, 0 in %rax, a pointer to the root of the expression structure in %rdi, a 
#    pointer to a vector of strings which represent the labels
#
# Modus Operandi
# --------------
# Go through all tokens 1 by 1, taking notes of the jumps and labels
#
# 1. 