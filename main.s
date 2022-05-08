# The mindbend compiler in assembly
# The functions in this program use the calling conventions used by Linux,
# passing arguments into registers in the following order:
# %rdi, %rsi, %rdx, %r10, %r8, %r9, then the stack, if needed
# Return values are passed into registers in the following order:
# %rax, %rdi, %rsi, %rdx, %r10, %r8, %r9
# Every symbol name has the naming convention of <filename>_<symbol name>

# The compiler does 5 things:
# 1. Parsing command line arguments and using them for input and configuration
# 2. Tokenizing input
# 3. Parsing
# 4. Code generation
# 5. Saving output to a file
#
# These tasks are seperated into 6 different files
# 1. main: the main driver, which coordinates the calling of functions
# 2. cmd_parser: for parsing command line arguments
#       The function used for the actual parsing is cmd_parser_parse_cmd_args
#       It either returns an error, indicated by a negative number
#       Or it returns the input filename, followed by the output filename
# 3. lexer: for tokenizing input
# 4. parser: for parsing tokens
# 5. codegen: for generating the actual code and saving it to a file
# 6. utils: for general utility functions used by other units

# Utils Required
# --------------
# Vectors
# Strings
# Heap Allocator
# read function
# print function
# strlen function

# Typical Compiler Flow, from the perspective of main
#
# At the beginning of the program, after the length of the file is gotten, 3 chunks of contiguous
# space should be allocated. One for the placement of the code itself, one for the vector of tokens
# and the last two for labels and jumps encountered in the code
# No space needs to be allocated for the code that will be generated, because code that will be
# generated will be written directly into a file
#
# Parsing command line args
# -------------------------
# 1. User enters commands
# 2. The argno is popped off the stack
# 3. The argno is placed in %rdi, as the first argument for cmd_parser_parse_cmd_args
# 4. %rdi is compared with 4
# 5. If %rdi is greater than 4, exit with error too many arguments
# 6. The arguments are popped off the stack and placed in registers %rsi down to %r10
# 7. cmd_parser_parse_cmd_args either returns an error, which will be a negative
#       number in %rax, a pointer to the error string in %rdi and the string length in %rsi,
#       or it's a success and returns either 0 in %rax, which signifies print help message or it
#       returns 1 in %rax, which signifies print version info or it
#       returns the pointer to the input filename, the length of the input filename, 
#       a pointer to the output filename and the length of the output filename
#       in %rax, %rdi, %rsi, and %rdx respectively
# 8. The result in %rax is compared to 0
# 9. If the result is lesser than 0, the string addressed in %rdi and
#       the usage are printed and the process exits with an error code
# 10. If the result is equal to 0, the help message is printed and the process exits with a success
# 11. If the result == 1, the version info is printed and the process exits with a success
# 11. The outfilename is saved on the stack
# 12. The input filename is passed as an argument to utils_open_file and utils_open_file is called
# 13. The utils_open_file function either returns an error, which will be a negative
#       number in %rax, a pointer to the error string in %rdi and the length of the error
#       in %rsi, or it's a success and returns the input file descriptor in %rax and the
#       number of bytes in %rdi
# 14. The number of bytes in %rdi is compared with 0
# 15. If it is 0, exit with error empty file
# 16. The utils_alloc function is passed the number of bytes in %rdi and is called
# 17. The utils_alloc function either returns an error, which will be a negative number in %rax,
#       a pointer to the error string in %rdi, and the length of the error in %rsi, or it's a success
#       and returns the address of the buffer to store the program in %rax, the address of the
#       vector to store tokens in %rdi and the address of the place to store the expression structure
#       for parsing in %rsi
#
# Tokenizing
# ----------
# 12. A pointer to the buffer contents and the length of it are passed as arguments to
#       tokenizer_tokenize and tokenizer_tokenize is called
# 13. tokenizer_tokenize either returns an error, which will be a negative number in %rax, a pointer
#       to the error string in %rdi and the string length in %rsi, or it's a success and returns a
#       0 in %rax, which signifies a success, and a pointer to a Vector of numbers, each of which
#       represents a token, in %rdi
# 14. The result in %rax is compared to 0
# 15. If the result is lesser than 0, the string addressed in %rdi is printed and the process exits
#
# Parsing
# -------
# 15. The vector of tokens is passed as an argument to parser_parse and parser_parse is
#       called
# 16. parser_parse either returns an error, which will be a negative number in %rax, a pointer to
#       the error string in %rdi and the length of the error string in %rsi, or it's a success and
#       returns 0 in %rax, a pointer to an OrganismExpression struct in %rdi, and a Vector of pointers
#       to strings which represent the labels
# 17. The result in %rax is compared with 0
# 18. If the result in %rax is lesser than 0, the string addressed in %rdi is printed and the process exits
# Codegen and Saving Output to File
# ---------------------------------
# 19. The OrgExpr pointer, Vector and out filename are passed as arguments to codegen_new_codegen and
#       codegen_new_codegen is called and a pointer to a CodeGen struct is returned in %rax
# 20. The pointer to the CodeGen struct is passed as an argument to codegen_code and codegen_code is called
# 21. codegen_code either returns an error, which will be a negative number in %rax, a pointer to the error
#       string in %rdi and the length of the error in %rsi, or it's a success and returns 0 in %rax
# 22. The result in %rax is compared with 0
# 23. If the result is lesser than 0, the string pointed to in %rdi is printed and the process exits
# 24. The process exits with a code of 0, meaning success

.include "utils.s"
.include "cmd_parser.s"
.include "lexer.s"
.include "parser.s"
.include "codegen.s"

.section .data
.usage_info:
    .equ USAGE_INFO_LEN, 86
    .asciz "USAGE:\n\tmindbend <input file> --output <output file>\n\nFor more information try --help\n"
.version_info:
    .equ VERSION_INFO_LEN, 15
    .asciz "mindbend 0.1.0\n"
.help_msg:
    .equ HELP_MSG_LEN, 309
    .asciz "mindbend 0.1.0\nDemilade Sonuga <sonugademilade8703@gmail.com>\n\nUSAGE:\n\tmindbend [OPTIONS] <input file>\n\nFLAGS:\t-h, --help\tPrints help information\n\t-V, --version\tPrints version information\n\nOPTIONS:\n\t-o, --output <output file> Name of output file [default: out]\n\nARGS:\n\t<input file>\tSource file to be compiled\n"
.no_args_error_msg:
    .equ NO_ARGS_ERR_MSG_LEN, 72
    .asciz "error: The following required arguments were not provided:\n\t<input file>\n"
.too_many_args_err_msg:
    .equ TOO_MANY_ARGS_ERR_MSG_LEN, 36
    .asciz "error: Too many arguments provided\n\n"
.too_few_args_err_msg:
    .equ TOO_FEW_ARGS_ERR_MSG_LEN, 29
    .asciz "error: Not enough arguments\n\n"
.err_msg_empty_input_file:
    .equ ERR_MSG_EMPTY_INPUT_FILE_LEN, 25
    .asciz "The input file is empty.\n"
.err_msg_generic:
    .equ ERR_MSG_GENERIC_LEN, 53
    .asciz "Something went wrong. (It's most likely your fault).\n"
.err_msg_assemble:
    .equ ERR_MSG_ASSEMBLE_LEN, 78
    .asciz "Something went wrong when assembling the code. (It's most likely your fault).\n"
.err_msg_link:
    .equ ERR_MSG_LINK_LEN, 75
    .asciz "Something went wrong when linking the code. (It's most likely your fault).\n"
.err_msg_rm:
    .equ ERR_MSG_RM_LEN, 89
    .asciz "Something went wrong when removing the intermediate file. (It's most likely your fault).\n"
.temp_out_filename:
    .asciz "out.tmp"
.gas_assembler:
    .equ GAS_ASSEMBLER_LEN, 7
    .asciz "/bin/as"
.gas_arg1:
    .asciz "-o"
.gas_arg2:
    .asciz "out.tmp"
.gas_env:
    .quad 0
.linker:
    .asciz "/bin/ld"
.linker_arg1:
    .asciz "out.tmp"
.linker_arg2:
    .asciz "-o"
.linker_env:
    .quad 0
.rm:
    .asciz "/bin/rm"
.rm_arg1:
    .asciz "out.tmp"
.rm_args:
    .quad .rm
    .quad .rm_arg1
    .quad 0
.rm_env:
    .quad 0

.section .bss
.struct_siginfo:
    .space 64
.struct_rusage:
    .space 64
.linker_args:
    .space 40
.gas_args:
    .space 40

.equ SYS_EXIT, 60
.equ SYS_FORK, 57
.equ SYS_WAIT, 247
.equ SYS_EXECVE, 59
.equ EXIT_SUCCESS, 0
.equ EXIT_ERR, 1

.section .text
.globl _start

_start:
    popq %rdi                   # The argument count
    cmp $4, %rdi
    jg exit_too_many_args       # 3 is the maximum number of arguments. The program name is counted
    cmp $2, %rdi                # 1 is the minimum. The program name is counted
    jl exit_too_few_args
    popq %rsi                   # Get rid of the program name
    popq %rsi                   # The first argument
    cmp $2, %rdi                # Is there only 1 argument?
    je parse_cmd_line_args
    popq %rdx                   # Put the next argument in %rdx
    cmp $3, %rdi                # Are there only 2 arguments?
    je parse_cmd_line_args
    popq %r10                   # At this point, there can be only 3 arguments. Put the last in %r10
    jmp parse_cmd_line_args

parse_cmd_line_args:
    call cmd_parser_parse_cmd_args
    cmp $0, %rax
    jl print_err_and_usage_and_exit
    je print_help_and_exit
    cmp $1, %rax
    je print_version_info_and_exit
    pushq %rsi                      # Saving the out filename
    movq %rax, %rdi                 # The input filename itself
    call utils_open_file
    cmp $0, %rax
    jl print_err_and_exit
    cmp $0, %rdi
    je print_empty_input_file_and_exit
    movq %rdi, %rsi                 # The number of bytes in the file
    movq %rax, %rdi                 # The input file descriptor
    pushq %rsi                      # The input file size
    pushq %rdi                      # Saving the input file descriptor
    call utils_alloc_main_space
    cmp $-1, %rax
    je print_err_and_exit
    popq %rdi                       # Restoring the file descriptor
    popq %rdx                       # Restoring the input file size
    pushq %rdx                      # Saving the input file size again
    pushq %rsi                      # Saving the address of the token space
    movq %rax, %rsi                 # The address of the space for the input file contents
    call utils_read_file
    cmp $0, %rax
    jl print_err_and_exit
    movq %rsi, %rdi                 # Address of input file content space
    popq %rdx                       # Restoring the address of the token space
    popq %rsi                       # Restoring the input file size
    jmp tokenize

tokenize:
    call lexer_tokenize
    cmp $0, %rax                    # Supposed to be number of tokens in token array
    jl print_err_and_exit
    pushq %rdx                      # Save address of token array
    pushq %rax                      # Save number of tokens
    movq %rax, %rdi
    imul $8, %rdi
    call utils_alloc                # Space to store encountered labels in parser
    cmp $0, %rax
    jl print_err_and_exit
    popq %rdi                       # Number of tokens
    pushq %rdi                      # Re-save the number of tokens
    imul $8, %rdi
    pushq %rax                      # Save address of space to store encountered labels
    call utils_alloc
    cmp $0, %rax
    jl print_err_and_exit
    movq %rax, %r10                 # Address of space for encountered jumps    
    popq %rdx                       # Address of space for encountered labels
    popq %rsi                       # Length of token array
    popq %rdi                       # Address of token space
    jmp parse

parse:
    call parser_parse
    cmp $0, %rax
    jl print_err_and_exit
    jmp codegen

codegen:
    # Create new file
    # Pass expression from parser, encountered labels and new file descriptor to codegen
    # Handle result
    popq %r8
    pushq %rdi                      # The address of the expression structure
    pushq %rsi                      # The address of the labels array
    pushq %rdx                      # The length of the encountered labels array
    movq %r8, %rdi
    call utils_create_file
    cmp $0, %rax
    jl print_err_and_exit
    popq %rdx
    popq %rsi
    popq %rdi
    pushq %r8                       # Save out filename
    movq %rax, %r10                 # The file descriptor of the output file
    call codegen_code
    cmp $0, %rax
    jl print_err_and_exit
    jmp assemble

assemble:
    .equ PID_TYPE, 1
    .equ OP_WAIT_FOR_EXIT, 4
    movq $SYS_FORK, %rax
    syscall
    cmp $0, %rax
    jl assemble_err
    je invoke_assembler
    movq $PID_TYPE, %rdi
    movq %rax, %rsi                         # Child PID
    leaq .struct_siginfo(%rip), %rdx        # Space for siginfo struct
    movq $OP_WAIT_FOR_EXIT, %r10
    leaq .struct_rusage(%rip), %r8
    movq $SYS_WAIT, %rax
    syscall
    cmp $0, %rax
    jl assemble_err
    jmp link

link:
    movq $SYS_FORK, %rax
    syscall
    cmp $0, %rax
    jl link_err
    je invoke_linker
    movq $PID_TYPE, %rdi
    movq %rax, %rsi
    leaq .struct_siginfo(%rip), %rdx
    movq $OP_WAIT_FOR_EXIT, %r10
    leaq .struct_rusage(%rip), %r8
    movq $SYS_WAIT, %rax
    syscall
    cmp $0, %rax
    jl link_err
    jmp remove_intermediate_file

remove_intermediate_file:
    movq $SYS_FORK, %rax
    syscall
    cmp $0, %rax
    jl link_err
    je invoke_rm
    movq $PID_TYPE, %rdi
    movq %rax, %rsi
    leaq .struct_siginfo(%rip), %rdx
    movq $OP_WAIT_FOR_EXIT, %r10
    leaq .struct_rusage(%rip), %r8
    movq $SYS_WAIT, %rax
    syscall
    cmp $0, %rax
    jl remove_intermediate_file_err
    jmp exit_success

invoke_assembler:
    leaq .gas_args(%rip), %rsi
    popq %r9                                # The out filename
    leaq .gas_assembler(%rip), %r15
    movq %r15, (%rsi)
    leaq .gas_arg1(%rip), %r15
    movq %r15, 8(%rsi)
    leaq .gas_arg2(%rip), %r15
    movq %r15, 16(%rsi)
    movq %r9, 24(%rsi)
    movq $0, 32(%rsi)
    movq $SYS_EXECVE, %rax
    leaq .gas_assembler(%rip), %rdi
    leaq .gas_env(%rip), %rdx
    syscall
    # Reaches here only if there is an error
    movq $EXIT_ERR, %rdi
    movq $60, %rax
    syscall

invoke_linker:
    leaq .linker_args(%rip), %rsi
    leaq .linker(%rip), %r15
    movq %r15, (%rsi)
    leaq .linker_arg1(%rip), %r15
    movq %r15, 8(%rsi)
    leaq .linker_arg2(%rip), %r15
    movq %r15, 16(%rsi)
    popq %r9                                # out filename
    movq %r9, 24(%rsi)
    movq $0, 32(%rsi)
    movq $SYS_EXECVE, %rax
    leaq .linker(%rip), %rdi
    leaq .linker_env(%rip), %rdx
    syscall
    movq $EXIT_ERR, %rdi
    movq $60, %rax
    syscall

invoke_rm:
    movq $SYS_EXECVE, %rax
    leaq .rm(%rip), %rdi
    leaq .rm_args(%rip), %rsi
    leaq .rm_env(%rip), %rdx
    syscall
    movq $EXIT_ERR, %rdi
    movq $SYS_EXIT, %rax
    syscall

assemble_err:
    leaq .err_msg_assemble(%rip), %rdi
    movq $ERR_MSG_ASSEMBLE_LEN, %rsi
    jmp print_err_and_exit

remove_intermediate_file_err:
    leaq .err_msg_rm(%rip), %rdi
    movq $ERR_MSG_RM_LEN, %rsi
    jmp print_err_and_exit

link_err:
    leaq .err_msg_link(%rip), %rdi
    movq $ERR_MSG_LINK_LEN, %rsi
    jmp print_err_and_exit

print_empty_input_file_and_exit:
    leaq .err_msg_empty_input_file(%rip), %rdi
    movq $ERR_MSG_EMPTY_INPUT_FILE_LEN, %rsi
    jmp print_err_and_exit

print_err_and_exit:
    call utils_print
    jmp exit_err

print_err_and_usage_and_exit:
    call utils_print
    leaq .usage_info(%rip), %rdi
    movq $USAGE_INFO_LEN, %rsi
    call utils_print
    jmp exit_err

print_help_and_exit:
    leaq .help_msg(%rip), %rdi
    movq $HELP_MSG_LEN, %rsi
    call utils_print
    jmp exit_success

print_version_info_and_exit:
    leaq .version_info(%rip), %rdi
    movq $VERSION_INFO_LEN, %rsi
    call utils_print
    jmp exit_success

exit_too_many_args:
    leaq .too_many_args_err_msg(%rip), %rdi
    movq $TOO_MANY_ARGS_ERR_MSG_LEN, %rsi
    jmp print_err_and_usage_and_exit

exit_too_few_args:
    leaq .too_few_args_err_msg(%rip), %rdi
    movq $TOO_FEW_ARGS_ERR_MSG_LEN, %rsi
    jmp print_err_and_usage_and_exit

exit_err:
    movq $SYS_EXIT, %rax
    movq $1, %rdi
    syscall

exit_success:
    movq $SYS_EXIT, %rax
    movq $0, %rdi
    syscall
    