# Role
# ----
# Parse command line args
# 
# Expected
# --------
# 1. The number of arguments + 1 (because of the program name) is stored in %rdi
# 2. The arguments are in %rsi, %rdx, %r10
#
# Result
# ------
# 1. In the case of an error, -1 in %rax, pointer to error string in %rdi, string length in %rsi
# 2. In the case of help, 0 in %rax
# 3. Else, pointer to input filename in %rax, length of the input filename in %rdi, pointer to the
#    output filename in %rsi, length of the output filename in %rdx
#
# Modus Operandi
# --------------
# In the following,
#   %r9 is used to know whether or not a current argument is the outfilename (1 means yes)
#   %r13 is used to know whether or not the input filename has already been parsed (1 means yes)
#   %r11 is used to know whether or not the out filename has already been parsed (1 means yes)
#   %r12 is used to hold the current argument
#   %r14 is used to hold the argument number of the current argument
#   %rbx is used to hold the out filename length
#   %rcx is used to hold the input filename length
#   %r8 is used to hold the out filename temporarily
#
# 3. Do the following initialization,
#       %r9 - 0
#       %r13 - 0
#       %r11 - 0
#       %r12 - 0
#       %r14 - 2 # 1 - Prog name 2,3,4 - 1st, 2nd and 3rd args
#       %rbx - 0
#       %rcx - 0
# Repeat the following for registers %rsi down to the last argument register till %r14 == %rdi
# 5. Compare the 1st letter of the argument with '-'
# 6. If it is '-', then it's an option, Compare the next letter with '-'
#   1. If the next letter is a '-', then it's a long word option, compare the next letter with 'o'
#       1. If the next letter is 'o', compare %r11 with 1
#           1. If %r11 is 1, then the out filename has already been parsed,
#               return error duplicate out filename definitions
#           1. Compare the remaining letters with 'utput'
#           2. If the argument is 'output'
#               1. Compare %r11 with 1
#               2. If %r11 is 1, then the out filename has already been parsed,
#                    return error duplicate out filename definitions
#               3. Compare %r9 with 1
#               4. If %r9 is 1, then this is supposed to be an out filename, which it is not
#                   return error duplicate out filename definitions
#               5. Set %r9 to 1, signifying the next argument is the outfilename
#               6. Move 1 into %r11
#           3. Else, return error unrecognized argument
#       2. If the next letter is not 'o', compare the next letter with 'h'
#           1. If it is 'h', repeat the process for 'elp' and return with 0 in %rax
#           2. If not, return error unrecognized argument
#       3. If the next letter is not 'h' compare the letter with 'v'
#           1. If it is 'v', repeat the process for 'ersion' and return with 1 in %rax
#           2. If not return error unrecognized argument
#       4. Else, return error unrecognized argument
#   2. If the next letter is not a '-', then it's a short one letter option
#       1. Compare the next letter with 'o'
#       2. If the next letter is 'o', compare %r11 with 1
#       3. If %r11 is 1, return error multiple definitions of outfile
#       4. If %r11 is not 1, compare the next letter with '\0'
#           1. If the next letter is '\0', then the next argument is the out filename, set %r9 to 1
#           2. If the next letter is not '\0', then the current letter downwards is the out filename
#               1. Move the current letter and all letters till '\0' to the left, overwriting the '-o'
#               2. Move 1 into %r11, signifying the out filename has been parsed
#               3. Move the current argument into %r8
#               4. Call strlen for the current argument
#               5. Move the result into %rbx
#       3. If the next letter is 'h', return with 0 in %rax, signifying print help message
#       4. Else, return error unrecognized argument
# 7. If it's not a '-', compare %r9 with 1
#       1. If %r9 is 1, then this argument is the out filename
#           1. Move the pointer to %r8
#           2. Call utils' strlen function to find the length of the string
#           3. Move the length of the string into %rbx
#           4. Move 0 into %r9
#       2. If %r9 is not 1, then this argument is not the out filename, compare %r13 with 1
#           1. If %r13 is 1, then the input filename has already been parsed,
#               return error unrecognized argument
#           2. If %r13 is not 1, then the input filename has not yet been parsed, move the pointer to
#               the string to %rax
#           3. Call strlen with the current argument as the argument
#           4. Move the result of strlen into %rcx
#           5. Move 1 into %r13
#           6. Move the argument into %rax
# 8. Increase %r14 by 1
# After the previous has been repeated for all arguments
# 10. If %rcx is 0, then the input filename was not provided,
#       return error required args not provided
# 11. Compare %rbx with 0
# 12. If %rbx is 0, then the output filename was not provided,
#       1. Move the pointer to the default output filename into %r8
#       2. Move the length of the default output filename into %rbx
# 13. Move %rbx into %rdx
# 14. Move %r8 into %rsi
# 15. Return
.section .data
.cmd_parser_mult_def_outfile_err:
    .equ CMD_PARSER_MULT_DEF_OUTFILE, 109
    .asciz "error: The argument '--output <output file>' was provided more than once, but cannot be used multiple times\n\n"

.unrecognized_arg_err_msg_begin:
    .equ UNRECOGNIZED_ARG_ERR_MSG_BEGIN_LEN, 23
    .asciz "error: Found argument '"

.unrecognized_arg_err_msg_end:
    .equ UNRECOGNIZED_ARG_ERR_MSG_END_LEN, 57
    .asciz "' which wasn't expected, or isn't valid in this context\n\n"

.required_args_not_provided_msg:
    .equ REQUIRED_ARGS_NOT_PROVIDED_MSG_LEN, 74
    .asciz "error: The following required arguments were not provided:\n\t<input file>\n\n"

.cmd_parser_default_out_filename:
    .equ DEFAULT_OUT_FILENAME_LEN, 3
    .asciz "out"

.cmd_parser_long_output_option:
    .asciz "--output"

.cmd_parser_long_help_option:
    .asciz "--help"

.cmd_parser_long_version_option:
    .asciz "--version"

.section .text
cmd_parser_parse_cmd_args:
    movq $0, %r9                        # Initialization
    movq $0, %r11
    movq $0, %r12
    movq $0, %r13
    movq $0, %rbx
    movq $0, %rcx
    movq $2, %r14
    jmp cmd_parser_parse_loop

cmd_parser_parse_loop:
    cmp %rdi, %r14                      # Any more arguments to process?
    jg cmd_parser_end_parse_loop
    cmp $2, %r14
    je cmd_parser_parse_first_arg
    cmp $3, %r14
    je cmd_parser_parse_second_arg
    jmp cmd_parser_parse_third_arg

cmd_parser_parse_first_arg:
    movq %rsi, %r12
    jmp cmd_parser_parse_arg

cmd_parser_parse_second_arg:
    movq %rdx, %r12
    jmp cmd_parser_parse_arg

cmd_parser_parse_third_arg:
    movq %r10, %r12
    jmp cmd_parser_parse_arg

cmd_parser_parse_arg:
    movq $0, %r15
    movb (%r12, %r15, 1), %r15b            # The first letter in the argument
    cmp $'-', %r15b
    je cmd_parser_parse_option
    cmp $1, %r9                            # Is this current argument the outfile
    je cmd_parser_set_current_arg_as_outfile
    cmp $1, %r13                           # Has the input filename been parsed?
    je cmd_parser_err_unrecognized_arg
    # The this argument must be the input filename
    movq %r12, %rax
    pushq %rax
    pushq %rdx
    pushq %rdi
    pushq %rsi
    pushq %r9
    pushq %r10
    pushq %r11
    pushq %r12
    pushq %r13
    pushq %r14
    movq %r12, %rdi
    call utils_strlen
    movq %rax, %rcx
    popq %r14
    popq %r13
    popq %r12
    popq %r11
    popq %r10
    popq %r9
    popq %rsi
    popq %rdi
    popq %rdx
    popq %rax
    movq $1, %r13           # The input filename has been parsed
    jmp cmd_parser_repeat_parse_loop

cmd_parser_parse_option:
    movq $1, %r15
    movb (%r12, %r15, 1), %r15b            # The second letter in the argument
    cmp $'-', %r15b
    je cmd_parser_parse_long_option        # The second '-' means it's a long option
    # Parsing short options
    cmp $'o', %r15b
    je cmd_parser_parse_output_file
    cmp $'h', %r15b
    je cmd_parser_return_help
    cmp $'V', %r15b
    je cmd_parser_return_version_info
    jmp cmd_parser_err_unrecognized_arg

cmd_parser_parse_long_option:
    pushq %rax
    call cmd_parser_is_option_long_output
    cmp $1, %rax
    popq %rax
    je cmd_parser_set_next_arg_as_outfile
    pushq %rax
    call cmd_parser_is_option_long_help
    cmp $1, %rax
    popq %rax
    je cmd_parser_return_help
    pushq %rax
    call cmd_parser_is_option_long_version
    cmp $1, %rax
    popq %rax
    je cmd_parser_return_version_info
    jmp cmd_parser_err_unrecognized_arg

cmd_parser_is_option_long_output:
    pushq %rcx
    pushq %rdx
    pushq %rdi
    pushq %rsi
    pushq %r9
    pushq %r10
    pushq %r11
    pushq %r12
    pushq %r13
    pushq %r14
    movq %r12, %rdi
    leaq .cmd_parser_long_output_option(%rip), %rsi
    call utils_streq
    popq %r14
    popq %r13
    popq %r12
    popq %r11
    popq %r10
    popq %r9
    popq %rsi
    popq %rdi
    popq %rdx
    popq %rcx
    ret

cmd_parser_is_option_long_help:
    pushq %rcx
    pushq %rdx
    pushq %rdi
    pushq %rsi
    pushq %r9
    pushq %r10
    pushq %r11
    pushq %r12
    pushq %r13
    pushq %r14
    movq %r12, %rdi
    leaq .cmd_parser_long_help_option(%rip), %rsi
    call utils_streq
    popq %r14
    popq %r13
    popq %r12
    popq %r11
    popq %r10
    popq %r9
    popq %rsi
    popq %rdi
    popq %rdx
    popq %rcx
    ret

cmd_parser_is_option_long_version:
    pushq %rcx
    pushq %rdx
    pushq %rdi
    pushq %rsi
    pushq %r9
    pushq %r10
    pushq %r11
    pushq %r12
    pushq %r13
    pushq %r14
    movq %r12, %rdi
    leaq .cmd_parser_long_version_option(%rip), %rsi
    call utils_streq
    popq %r14
    popq %r13
    popq %r12
    popq %r11
    popq %r10
    popq %r9
    popq %rsi
    popq %rdi
    popq %rdx
    popq %rcx
    ret

cmd_parser_parse_long_help_option:
    movq %r12, %rdi
    leaq .cmd_parser_long_help_option(%rip), %rsi
    call utils_streq
    cmp $0, %rax        # The argument is not the long output argument
    je cmd_parser_err_unrecognized_arg
    jmp cmd_parser_return_help

cmd_parser_parse_long_version_option:
    movq %r12, %rdi
    leaq .cmd_parser_long_version_option(%rip), %rsi
    call utils_streq
    cmp $0, %rax        # The argument is not the long output argument
    je cmd_parser_err_unrecognized_arg
    jmp cmd_parser_return_version_info

cmd_parser_parse_output_file:
    cmp $1, %r11                        # Has the outfile already been defined?
    je cmd_parser_err_multiple_definitions_of_outfile
    cmp $1, %r9                         # Is this argument supposed to be an outfile?
    je cmd_parser_err_multiple_definitions_of_outfile
    movq $2, %r15
    movb (%r12, %r15, 1), %r15b         # The third letter in the argument
    cmp $0, %r15b
    je cmd_parser_set_next_arg_as_outfile
    # Shifting the '-o' in the outfile name out of the name
    pushq %rcx                      # Save the value in %rcx
    movq $2, %r8                    # Initializing the index to move from to 0
    jmp cmd_parser_extract_outfile_name_from_arg_loop

cmd_parser_extract_outfile_name_from_arg_loop:
    movb (%r12, %r8, 1), %r15b
    movq %r8, %rcx
    subq $2, %rcx
    movb %r15b, (%r12, %rcx, 1)
    cmp $0, %r15b
    je cmd_parser_extract_outfile_name_from_arg_loop_end
    incq %r8
    jmp cmd_parser_extract_outfile_name_from_arg_loop

cmd_parser_extract_outfile_name_from_arg_loop_end:
    popq %rcx                   # Restore %rcx
    jmp cmd_parser_set_current_arg_as_outfile

cmd_parser_set_current_arg_as_outfile:
    pushq %rax
    pushq %rcx
    pushq %rdx
    pushq %rdi
    pushq %rsi
    pushq %r9
    pushq %r10
    pushq %r11
    pushq %r12
    pushq %r13
    pushq %r14
    movq %r12, %rdi
    call utils_strlen
    movq %rax, %rbx
    popq %r14
    popq %r13
    popq %r12
    popq %r11
    popq %r10
    popq %r9
    popq %rsi
    popq %rdi
    popq %rdx
    popq %rcx
    popq %rax
    movq $1, %r11           # The outfile name has been parsed
    movq $0, %r9            # The next argument is not an out filename
    movq %r12, %r8          # The parsed outfile name
    jmp cmd_parser_repeat_parse_loop

cmd_parser_set_next_arg_as_outfile:
    movq $1, %r9                        # Signifying the next arg as an outfile
    jmp cmd_parser_repeat_parse_loop

cmd_parser_repeat_parse_loop:
    incq %r14
    jmp cmd_parser_parse_loop

cmd_parser_end_parse_loop:
    cmp $0, %rcx
    je cmd_parser_err_required_args_not_provided
    cmp $0, %rbx                # Was the outfile name provided?
    je cmd_parser_set_out_filename_to_default
    jmp cmd_parser_continue_end_parse_loop

cmd_parser_set_out_filename_to_default:
    leaq .cmd_parser_default_out_filename(%rip), %r8
    movq $DEFAULT_OUT_FILENAME_LEN, %rbx
    jmp cmd_parser_continue_end_parse_loop

cmd_parser_continue_end_parse_loop:
    movq %rbx, %rdx
    movq %r8, %rsi
    ret

cmd_parser_return_help:
    movq $0, %rax
    ret

cmd_parser_return_version_info:
    movq $1, %rax
    ret

cmd_parser_err_multiple_definitions_of_outfile:
    movq $-1, %rax
    leaq .cmd_parser_mult_def_outfile_err(%rip), %rdi
    movq $CMD_PARSER_MULT_DEF_OUTFILE, %rsi
    ret

cmd_parser_err_unrecognized_arg:
    leaq .unrecognized_arg_err_msg_begin(%rip), %rdi
    movq $UNRECOGNIZED_ARG_ERR_MSG_BEGIN_LEN, %rsi
    call utils_print                                    # Print the first part of the message
    movq %r12, %rdi
    call utils_strlen
    movq %rax, %rsi
    call utils_print                                    # Print the unknown string
    leaq .unrecognized_arg_err_msg_end(%rip), %rdi
    movq $UNRECOGNIZED_ARG_ERR_MSG_END_LEN, %rsi
    movq $-1, %rax
    ret                                                 # Return the rest of the error

cmd_parser_err_required_args_not_provided:
    movq $-1, %rax
    leaq .required_args_not_provided_msg(%rip), %rdi
    movq $REQUIRED_ARGS_NOT_PROVIDED_MSG_LEN, %rsi
    ret