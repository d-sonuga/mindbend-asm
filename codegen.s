# Role
# ----
# Turn an expression structure into executable code
#
# Expected
# --------
# 1. Address of expression structure is in %rdi
# 2. Address of labels array is in %rsi
# 3. Length of labels array is in %rdx
# 4. File descriptor of output file is in %r10
#
# Result
# ------
# 1. In the case of an error, -1 in %rax, the address of the error string in %rdi, the string length in %rsi
# 2. In the case of a success, 0 in %rax
#
# Modus Operandi
# --------------
# 1. Code the preliminaries, that is, the routines and functions that all mindbend programs
#    must have.
# 2. Initialize the Data Landscape
#
# Runtime Info
# ------------
# The following are for the generated code, and not the code in this file
#
# The Data Landscape
# ------------------
# All Data Landscape values are stored on the stack and are to be accessed by the base pointer
# They are laid out in the following order
# The Current Gates State (CGS)             - initialized to 0 (0 gates open). Position 0
# The gates Time To Stay Open (TTSO)        - initialized to 5.                Position -8
# The Current Region (CR)                   - initialized to 0 (Cells Region)  Position -16
# The Representation of the Cells Region    - 15 contiguous spaces. Don't need initialization   Position -24
# The TTL table                             - 15 contiguous spaces. Initialized to 0.       Position -144
# The TTL table ends at position -263
# The stack pointer should point to the position -264 after the Data Landscape initialization
# Each value has a size of 8 bytes
#
# Routines
# --------
# The routines begin with the assumption that the Data Landscape has been initialized
# A return value of 0 in %rax represents success
# A return value of -1 in %rax represents fail

.section .data
.equ TTL_OFFSET, 144
.equ CGS_OFFSET, 0
.equ TTSO_OFFSET, 8
.equ CR_OFFSET, 16
.equ CELLS_OFFSET, 24
.preamble_code:
    .equ PREAMBLE_CODE_LEN, 12161
    .asciz "
.section .data
.primitive_access_gates_not_open_err_msg:
    .equ PRIMITIVE_ACCESS_GATES_NOT_OPEN_ERR_MSG_LEN, 89
    .asciz \"Attempting to access primitive when gates aren't fully open at the nth position. Find n.\\n\"
.primitive_access_layers_not_region_err_msg:
    .equ PRIMITIVE_ACCESS_LAYERS_NOT_REGION_ERR_MSG_LEN, 85
    .asciz \"Attempting to access primitive outside the Layers Region at the nth position. Find n.\\n\"
.drill_gate_not_layers_err_msg:
    .equ DRILL_GATE_NOT_LAYERS_ERR_MSG_LEN, 82
    .asciz \"Attempting to drill gates when not in Layers Region at the nth position. Find n.\\n\"
.cell_access_routine_err_not_cells_region_err_msg:
    .equ CELL_ACCESS_ROUTINE_ERR_NOT_CELLS_REGION_ERR_MSG_LEN, 81
    .asciz \"Attempting to access Cell when not in Cells Region at the nth position. Find n.\\n\"
.expression_life_validation_routine_err_dead_cell_err_msg:
    .equ EXPRESSION_LIFE_VALIDATION_ROUTINE_ERR_DEAD_CELL_ERR_MSG_LEN, 73
    .asciz \"Attempting to make use of Death Expression at the nth position. Find n.\\n\"
.function_validation_routine_err_dead_cell_err_msg:
    .equ FUNCTION_VALIDATION_ROUTINE_ERR_DEAD_CELL_ERR_MSG_LEN, 83
    .asciz \"Attempting to use Death Expression to go on massacre at the nth position. Find n.\\n\"
.function_validation_routine_err_not_a_function_err_msg:
    .equ FUNCTION_VALIDATION_ROUTINE_ERR_NOT_A_FUNCTION_ERR_MSG_LEN, 99
    .asciz \"Attempting to use expression without rampage power to go on massacre at the nth position. Find n.\\n\"
.function_execution_routine_err_death_expr_arg_err_msg:
    .equ FUNCTION_EXECUTION_ROUTINE_ERR_DEATH_EXPR_ARG_ERR_MSG_LEN, 74
    .asciz \"Attempting to consume Death Expression in massacre at position n. Find n.\\n\"

.section .bss
.char_to_print:
    .byte 0
.char_gotten:
    .byte 0

.section .text
.globl _start

_start:
    jmp init_data_landscape

# 1 represents the Layers Region
# 0 represents the Cells Region
primitive_access_routine:
    cmp $1, -16(%rbp)
    jne primitive_access_routine_err_not_layers_region
    cmp $3, (%rbp)
    jne primitive_access_routine_err_gates_not_open
    movq $0, %rax
    ret

primitive_access_routine_err_not_layers_region:
    leaq .primitive_access_layers_not_region_err_msg(%rip), %rdi
    movq $PRIMITIVE_ACCESS_LAYERS_NOT_REGION_ERR_MSG_LEN, %rsi
    movq $-1, %rax
    ret

primitive_access_routine_err_gates_not_open:
    leaq .primitive_access_gates_not_open_err_msg(%rip), %rdi
    movq $PRIMITIVE_ACCESS_GATES_NOT_OPEN_ERR_MSG_LEN, %rsi
    movq $-1, %rax
    ret

drill_gate_routine:
    cmp $1, -16(%rbp)
    jne drill_gate_routine_err_not_layers
    cmp $3, (%rbp)
    je drill_gate_routine_end
    incq (%rbp)
    cmp $3, (%rbp)
    je drill_gate_routine_update_ttso
    jmp drill_gate_routine_end

drill_gate_routine_err_not_layers:
    leaq .drill_gate_not_layers_err_msg(%rip), %rdi
    movq $DRILL_GATE_NOT_LAYERS_ERR_MSG_LEN, %rsi
    movq $-1, %rax
    ret

drill_gate_routine_update_ttso:
    movq $5, -8(%rbp)
    jmp drill_gate_routine_end

drill_gate_routine_end:
    movq $0, %rax
    ret

cell_access_routine:
    cmp $0, -16(%rbp)
    jne cell_access_routine_err_not_cells_region
    movq $0, %rax
    ret

cell_access_routine_err_not_cells_region:
    leaq .cell_access_routine_err_not_cells_region_err_msg(%rip), %rdi
    movq $CELL_ACCESS_ROUTINE_ERR_NOT_CELLS_REGION_ERR_MSG_LEN, %rsi
    movq $-1, %rax
    ret

# The cell number will be placed in %r15
expression_life_validation_routine:
    pushq %r14
    pushq %r15
    movq %rbp, %r14
    subq $144, %r14
    imul $-1, %r15
    cmp $0, (%r14, %r15, 8)
    je expression_life_validation_routine_err_dead_cell
    movq $0, %rax
    popq %r15
    popq %r14
    ret

expression_life_validation_routine_err_dead_cell:
    popq %r15
    popq %r14
    leaq .expression_life_validation_routine_err_dead_cell_err_msg(%rip), %rdi
    movq $EXPRESSION_LIFE_VALIDATION_ROUTINE_ERR_DEAD_CELL_ERR_MSG_LEN, %rsi
    movq $-1, %rax
    ret

# The cell number of the expression being validated will be placed in %r15
function_validation_routine:
    pushq %r15
    pushq %r14
    movq %rbp, %r14
    subq $144, %r14
    imul $-1, %r15
    cmp $0, (%r14, %r15, 8)
    je function_validation_routine_err_dead_cell
    movq %rbp, %r14
    subq $24, %r14
    movq (%r14, %r15, 8), %r14
    cmp $0, %r14
    je function_validation_routine_success
    cmp $1, %r14
    je function_validation_routine_success
    cmp $2, %r14
    je function_validation_routine_success
    cmp $3, %r14
    je function_validation_routine_success
    jmp function_validation_routine_err_not_a_function

function_validation_routine_err_dead_cell:
    popq %r14
    popq %r15
    leaq .function_validation_routine_err_dead_cell_err_msg(%rip), %rdi
    movq $FUNCTION_VALIDATION_ROUTINE_ERR_DEAD_CELL_ERR_MSG_LEN, %rsi
    movq $-1, %rax
    ret

function_validation_routine_err_not_a_function:
    popq %r14
    popq %r15
    leaq .function_validation_routine_err_not_a_function_err_msg(%rip), %rdi
    movq $FUNCTION_VALIDATION_ROUTINE_ERR_NOT_A_FUNCTION_ERR_MSG_LEN, %rsi
    movq $-1, %rax
    ret

function_validation_routine_success:
    popq %r14
    popq %r15
    movq $0, %rax
    ret

# Cell number, base address of args array on stack and number of args
# will be placed in %r15, %r14 and %r13 respectively
function_execution_routine:
    movq $0, %r12               # Starting index of args
    movq %rbp, %r9
    subq $24, %r9
    imul $-1, %r15
    movq (%r9, %r15, 8), %r15
    cmp $0, %r15
    je function_execute_subtraction
    cmp $1, %r15
    je function_execute_addition
    cmp $2, %r15
    je function_execute_output
    jmp function_execute_input

function_execute_subtraction:
    cmp $1, %r13
    je function_execute_subtraction_one_arg
    jmp function_execute_subtraction_multiple_args

function_execute_subtraction_one_arg:
    movq (%r14, %r12, 8), %r11
    movq %r11, %r15
    call expression_life_validation_routine
    cmp $-1, %rax
    je function_execute_err_dead_arg
    movq %rbp, %r9
    subq $24, %r9
    imul $-1, %r11
    movq $0, (%r9, %r11, 8)
    jmp function_execute_end

function_execute_subtraction_multiple_args:
    movq (%r14, %r12, 8), %r11
    movq %r11, %r15
    call expression_life_validation_routine
    cmp $-1, %rax
    je function_execute_err_dead_arg
    movq %rbp, %r9
    subq $24, %r9                 # Offset of cell value from base pointer
    imul $-1, %r11
    movq (%r9, %r11, 8), %r10     # Result initialized to first cell value
    jmp function_execute_subtraction_multiple_args_loop

function_execute_subtraction_multiple_args_loop:
    decq %r12
    movq %r12, %rcx
    addq %r13, %rcx
    jz function_execute_end
    movq (%r14, %r12, 8), %r11
    movq %r11, %r15
    call expression_life_validation_routine
    cmp $-1, %rax
    je function_execute_err_dead_arg
    movq %rbp, %r9
    subq $24, %r9
    imul $-1, %r11
    subq (%r9, %r11, 8), %r10
    jmp function_execute_subtraction_multiple_args_loop

function_execute_addition:
    cmp $1, %r13
    je function_execute_addition_one_arg
    jmp function_execute_addition_multiple_args

function_execute_addition_one_arg:
    movq (%r14, %r12, 8), %r11
    movq %r11, %r15
    call expression_life_validation_routine
    cmp $-1, %rax
    je function_execute_err_dead_arg
    movq %rbp, %r9
    subq $24, %r9
    imul $-1, %r11
    movq (%r9, %r11, 8), %r10
    addq %r10, %r10
    movq %r10, (%r9, %r11, 8)
    jmp function_execute_end

function_execute_addition_multiple_args:
    movq (%r14, %r12, 8), %r11
    movq %r11, %r15
    call expression_life_validation_routine
    cmp $-1, %rax
    je function_execute_err_dead_arg
    movq %rbp, %r9
    subq $24, %r9
    imul $-1, %r11
    movq (%r9, %r11, 8), %r10
    jmp function_execute_addition_multiple_args_loop

function_execute_addition_multiple_args_loop:
    decq %r12
    movq %r12, %rcx
    addq %r13, %rcx
    jz function_execute_end
    movq (%r14, %r12, 8), %r11
    movq %r11, %r15
    call expression_life_validation_routine
    cmp $-1, %rax
    je function_execute_err_dead_arg
    movq %rbp, %r9
    subq $24, %r9
    imul $-1, %r11
    addq (%r9, %r11, 8), %r10
    jmp function_execute_addition_multiple_args_loop

function_execute_output:
    cmp $1, %r13
    je function_execute_output_one_arg
    jmp function_execute_output_multiple_args

function_execute_output_one_arg:
    movq (%r14, %r12, 8), %r11
    movq %r11, %r15
    call expression_life_validation_routine
    cmp $-1, %rax
    je function_execute_err_dead_arg
    movq %rbp, %r9
    subq $24, %r9
    imul $-1, %r11
    movq (%r9, %r11, 8), %r10
    call putchar
    jmp function_execute_end

function_execute_output_multiple_args:
    movq (%r14, %r12, 8), %r11
    movq %r11, %r15
    call expression_life_validation_routine
    cmp $-1, %rax
    je function_execute_err_dead_arg
    movq %rbp, %r9
    subq $24, %r9
    imul $-1, %r11
    movq (%r9, %r11, 8), %r10
    decq %r12
    movq %r12, %rcx
    addq %r13, %rcx
    jz function_execute_output_one_arg
    movq (%r14, %r12, 8), %r11
    movq %r11, %r15
    call expression_life_validation_routine
    cmp $-1, %rax
    je function_execute_err_dead_arg
    imul $-1, %r11
    movq (%r9, %r11, 8), %r8
    imul $10, %r10
    addq %r8, %r10
    movq %r10, %rdi
    call putchar
    decq %r12
    movq %r12, %rcx
    addq %r13, %rcx
    jz function_execute_end
    jmp function_execute_output_multiple_args

function_execute_input:
    movq (%r14, %r12, 8), %r15
    call expression_life_validation_routine
    cmp $-1, %rax
    je function_execute_err_dead_arg
    decq %r12
    movq %r12, %rcx
    addq %r13, %r12
    jz function_execute_input_end
    jmp function_execute_input

function_execute_input_end:
    call getchar
    movq %r13, %r12
    decq %r12
    imul $-1, %r12
    movq (%r14, %r12, 8), %r10
    movq %rbp, %r9
    subq $24, %r9
    imul $-1, %r10
    movq %rax, (%r9, %r10, 8)
    jmp function_execute_end

function_execute_end:
    # call state_update_routine
    movq $0, %r12
    movq %r13, %r10
    decq %r10
    imul $-1, %r10
    movq (%r14, %r10, 8), %r11
    movq %rbp, %r9
    subq $144, %r9
    imul $-1, %r11
    movq $5, (%r9, %r11, 8)
    jmp function_execute_kill_args_revive_last

function_execute_kill_args_revive_last:
    cmp %r12, %r10
    je function_execute_return
    movq (%r14, %r12, 8), %r11
    movq %rbp, %r9
    subq $144, %r9
    imul $-1, %r11
    movq $0, (%r9, %r11, 8)
    decq %r12
    jmp function_execute_kill_args_revive_last

function_execute_err_dead_arg:
    leaq .function_execution_routine_err_death_expr_arg_err_msg(%rip), %rdi
    movq $FUNCTION_EXECUTION_ROUTINE_ERR_DEATH_EXPR_ARG_ERR_MSG_LEN, %rsi
    ret

function_execute_return:
    movq $0, %rax
    ret

init_data_landscape:
    movq %rsp, %rbp
    subq $264, %rsp
    movq $0, (%rbp)
    movq $5, -8(%rbp)
    movq $0, -16(%rbp)
    movq $0, -144(%rbp)
    movq $0, -152(%rbp)
    movq $0, -160(%rbp)
    movq $0, -168(%rbp)
    movq $0, -176(%rbp)
    movq $0, -184(%rbp)
    movq $0, -192(%rbp)
    movq $0, -200(%rbp)
    movq $0, -208(%rbp)
    movq $0, -216(%rbp)
    movq $0, -224(%rbp)
    movq $0, -232(%rbp)
    movq $0, -240(%rbp)
    movq $0, -248(%rbp)
    movq $0, -256(%rbp)
    jmp main

print:
    pushq %r8
    pushq %r9
    pushq %rax
    pushq %rdx
    pushq %rcx
    pushq %r11
    movq %rdi, %r8
    movq %rsi, %r9
    movq $1, %rax 
    movq $1, %rdi           
    movq %r8, %rsi
    movq %r9, %rdx
    syscall
    popq %r11
    popq %rcx
    popq %rdx
    popq %rax
    popq %r9
    popq %r8
    ret

putchar:
    pushq %r8
    pushq %rsi
    movq %rdi, %r8
    leaq .char_to_print(%rip), %rdi
    movb %r8b, (%rdi)
    movq $1, %rsi
    call print
    popq %rsi
    popq %r8
    ret

getchar:
    pushq %rdi
    pushq %rsi
    pushq %rdx
    movq $2, %rdi           # Standard input
    leaq .char_gotten(%rip), %rsi
    movq $1, %rdx
    movq $0, %rax
    syscall
    movq (%rsi), %rax
    popq %rdx
    popq %rsi
    popq %rdi
    ret

print_err_and_exit:
    call print
    jmp end_fail

end_success:
    movq $60, %rax
    movq $0, %rdi
    syscall

end_fail:
    movq $60, %rax
    movq $1, %rdi
    syscall

main:
"

.call_par_code:
    .equ CALL_PAR_CODE_LEN, 79
    .asciz "
    call primitive_access_routine
    cmp $-1, %rax
    je print_err_and_exit
"

.call_dgr_code:
    .equ CALL_DGR_CODE_LEN, 73
    .asciz "
    call drill_gate_routine
    cmp $-1, %rax
    je print_err_and_exit
"

.call_car_code:
    .equ CALL_CAR_CODE_LEN, 74
    .asciz "
    call cell_access_routine
    cmp $-1, %rax
    je print_err_and_exit
"

.call_elvr_code:
    .equ CALL_ELVR_CODE_LEN, 89
    .asciz "
    call expression_life_validation_routine
    cmp $-1, %rax
    je print_err_and_exit
"

.call_fvr_code:
    .equ CALL_FVR_CODE_LEN, 82
    .asciz "
    call function_validation_routine
    cmp $-1, %rax
    je print_err_and_exit
"

.call_fer_code:
    .equ CALL_FER_CODE_LEN, 81
    .asciz "
    call function_execution_routine
    cmp $-1, %rax
    je print_err_and_exit
"

.change_region_to_cells_code:
    .equ CHANGE_REGION_TO_CELLS_CODE_LEN, 23
    .asciz "
    movq $0, -16(%rbp)
"

.change_region_to_layers_code:
    .equ CHANGE_REGION_TO_LAYERS_CODE_LEN, 23
    .asciz "
    movq $1, -16(%rbp)
"

.jump_to_label_code_start:
    .equ JUMP_TO_LABEL_CODE_START_LEN, 9
    .asciz "
    jmp "

.jump_to_label_code_end:
    .equ JUMP_TO_LABEL_CODE_END_LEN, 1
    .asciz "\n"

.label_code_end:
    .equ LABEL_CODE_END_LEN, 2
    .asciz ":\n"

.jump_code_start:
    .equ JUMP_CODE_START_LEN, 5
    .asciz "\tjmp "

.jump_code_end:
    .equ JUMP_CODE_END_LEN, 1
    .asciz "\n"

.jump_end_success:
    .equ JUMP_END_SUCCESS_LEN, 17
    .asciz "\tjmp end_success\n"

.mov_0:
    .equ MOV_0_LEN, 10
    .asciz "\tmovq $0, "

.mov_1:
    .equ MOV_1_LEN, 10
    .asciz "\tmovq $1, "

.mov_2:
    .equ MOV_2_LEN, 10
    .asciz "\tmovq $2, "

.mov_3:
    .equ MOV_3_LEN, 10
    .asciz "\tmovq $3, "

.mov_4:
    .equ MOV_4_LEN, 10
    .asciz "\tmovq $4, "

.mov_5:
    .equ MOV_5_LEN, 10
    .asciz "\tmovq $5, "

.mov_6:
    .equ MOV_6_LEN, 10
    .asciz "\tmovq $6, "

.mov_7:
    .equ MOV_7_LEN, 10
    .asciz "\tmovq $7, "

.mov_8:
    .equ MOV_8_LEN, 10
    .asciz "\tmovq $8, "

.mov_9:
    .equ MOV_9_LEN, 10
    .asciz "\tmovq $9, "

.deref_base_pointer:
    .equ DEREF_BASE_POINTER_LEN, 7
    .asciz "(%rbp)\n"

.deref_base_pointer_no_newline:
    .equ DEREF_BASE_POINTER_NO_NEWLINE_LEN, 6
    .asciz "(%rbp)"

.mov_num_start:
    .equ MOV_NUM_START_LEN, 7
    .asciz "\tmovq $"

.mov_start:
    .equ MOV_START_LEN, 6
    .asciz "\tmovq "

.r15:
    .equ R15_LEN, 4
    .asciz "%r15"

.comma:
    .equ COMMA_LEN, 2
    .asciz ", "

.args_array_init_code:
    .equ ARGS_ARRAY_INIT_CODE_LEN, 32
    .asciz "\tmovq %rsp, %r14\n\tsubq $8, %r14\n"

.push_int_start_code:
    .equ PUSH_INT_START_CODE_LEN, 8
    .asciz "\tpushq $"

.r13:
    .equ R13_LEN, 4
    .asciz "%r13"

.pop_r15_code:
    .equ POP_R15_CODE_LEN, 11
    .asciz "\tpopq %r15\n"

.section .text
codegen_code:
    pushq %rdi
    pushq %rsi
    pushq %rdx
    movq %r10, %rdi
    leaq .preamble_code(%rip), %rsi                    # Coding preliminaries
    movq $PREAMBLE_CODE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_err_write
    popq %rdx
    popq %rsi
    popq %rdi
    jmp codegen_code_loop
    ret

codegen_code_err_write:
    popq %rax
    popq %rax
    popq %rax
    movq $-1, %rax
    ret                                         # Return the error

codegen_code_loop:
    movq ORG_EXPR_CHILD_OFFSET(%rdi), %r8       # Address of current Organism Expression child
    cmpb $PRIMITIVE_EXPRESSION, (%r8)
    je codegen_code_lone_primitive_expr
    cmpb $REGION_EXPRESSION, (%r8)
    je codegen_code_region_expr
    cmpb $LABEL_EXPRESSION, (%r8)
    je codegen_code_label_expr
    cmpb $JUMP_EXPRESSION, (%r8)
    je codegen_code_jump_expr
    cmpb $DRILL_EXPRESSION, (%r8)
    je codegen_code_drill_expr
    cmpb $CELL_EXPRESSION, (%r8)
    je codegen_code_lone_cell_expr
    cmpb $LEACH_EXPRESSION, (%r8)
    je codegen_code_leach_expr
    ret

codegen_code_loop_repeat:
    movq ORG_EXPR_NEXT_ORG_OFFSET(%rdi), %rdi
    cmp $NULL_EXPRESSION, (%rdi)
    je codegen_code_loop_end
    jmp codegen_code_loop

codegen_code_loop_end:
    leaq .jump_end_success(%rip), %rsi
    movq $JUMP_END_SUCCESS_LEN, %rdx
    movq %r10, %rdi
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_loop_end_err
    movq $0, %rax
    ret

codegen_code_loop_end_err:
    movq $-1, %rax
    ret

codegen_code_lone_primitive_expr:
    pushq %rdi
    pushq %rsi
    pushq %rdx
    movq %r10, %rdi
    leaq .call_par_code(%rip), %rsi
    movq $CALL_PAR_CODE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_lone_primitive_expr_err_write
    popq %rdx
    popq %rsi
    popq %rdi
    jmp codegen_code_loop_repeat

codegen_code_lone_primitive_expr_err_write:
    popq %rax
    popq %rax
    popq %rax
    movq $-1, %rax
    ret

codegen_code_region_expr:
    movb REGION_EXPR_IDENT_ADDR_OFFSET(%r8), %r15b        # Region number
    cmpb $CELLS_REGION, %r15b
    je codegen_code_region_expr_cells
    jmp codegen_code_region_expr_layers

codegen_code_region_expr_cells:
    pushq %rdi
    pushq %rsi
    pushq %rdx
    movq %r10, %rdi
    leaq .change_region_to_cells_code(%rip), %rsi
    movq $CHANGE_REGION_TO_CELLS_CODE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_region_expr_err_write
    popq %rdx
    popq %rsi
    popq %rdi
    jmp codegen_code_loop_repeat
    
codegen_code_region_expr_layers:
    pushq %rdi
    pushq %rsi
    pushq %rdx
    movq %r10, %rdi
    leaq .change_region_to_layers_code(%rip), %rsi
    movq $CHANGE_REGION_TO_LAYERS_CODE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_region_expr_err_write
    popq %rdx
    popq %rsi
    popq %rdi
    jmp codegen_code_loop_repeat

codegen_code_region_expr_err_write:
    popq %rax
    popq %rax
    popq %rax
    movq $-1, %rax
    ret

codegen_code_label_expr:
    pushq %rdi
    pushq %rsi
    pushq %rdx
    movq %r10, %rdi
    leaq .jump_to_label_code_start(%rip), %rsi
    movq $JUMP_TO_LABEL_CODE_START_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_label_expr_err_write
    movq LABEL_EXPR_NAME_ADDR_OFFSET(%r8), %rdi
    call utils_strlen
    movq %rax, %rdx
    movq %rdi, %rsi
    movq %r10, %rdi
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_label_expr_err_write
    movq %rdx, %r13                             # Save the label length
    leaq .jump_to_label_code_end(%rip), %rsi
    movq $JUMP_TO_LABEL_CODE_END_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_label_expr_err_write
    movq LABEL_EXPR_NAME_ADDR_OFFSET(%r8), %rsi
    movq %r13, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_label_expr_err_write
    leaq .label_code_end(%rip), %rsi
    movq $LABEL_CODE_END_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_label_expr_err_write
    popq %rdx
    popq %rsi
    popq %rdi
    jmp codegen_code_loop_repeat
    
codegen_code_label_expr_err_write:
    popq %rax
    popq %rax
    popq %rax
    movq $-1, %rax
    ret

codegen_code_jump_expr:
    pushq %rdi
    pushq %rsi
    pushq %rdx
    movq %r10, %rdi
    leaq .jump_code_start(%rip), %rsi
    movq $JUMP_CODE_START_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_jump_expr_err_write
    movq JUMP_EXPR_NAME_ADDR_OFFSET(%r8), %rdi
    call utils_strlen
    movq %rdi, %rsi
    movq %r10, %rdi
    movq %rax, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_jump_expr_err_write
    leaq .jump_code_end(%rip), %rsi
    movq $JUMP_CODE_END_LEN, %rdx
    call utils_write_file
    popq %rdx
    popq %rsi
    popq %rdi
    jmp codegen_code_loop_repeat

codegen_code_jump_expr_err_write:
    popq %rax
    popq %rax
    popq %rax
    movq $-1, %rax
    ret

codegen_code_drill_expr:
    pushq %rdi
    pushq %rsi
    pushq %rdx
    movq %r10, %rdi
    leaq .call_dgr_code(%rip), %rsi
    movq $CALL_DGR_CODE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_drill_expr_err_write
    popq %rdx
    popq %rsi
    popq %rdi
    jmp codegen_code_loop_repeat

codegen_code_drill_expr_err_write:
    popq %rax
    popq %rax
    popq %rax
    movq $-1, %rax
    ret

codegen_code_lone_cell_expr:
    pushq %rdi
    pushq %rsi
    pushq %rdx
    movq %r10, %rdi
    leaq .call_car_code(%rip), %rsi
    movq $CALL_CAR_CODE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_lone_cell_expr_err_write
    popq %rdx
    popq %rsi
    popq %rdi
    jmp codegen_code_loop_repeat

codegen_code_lone_cell_expr_err_write:
    popq %rax
    popq %rax
    popq %rax
    movq $-1, %rax
    ret

codegen_code_leach_expr:
    pushq %rdi
    pushq %rsi
    pushq %rdx
    movq %r10, %rdi
    movq LEACH_EXPR_LEFT_EXPR_OFFSET(%r8), %r14     # Address of left expression
    cmpb $PRIMITIVE_EXPRESSION, (%r14)
    je codegen_code_leach_primitive_expr
    cmpb $1, LEACH_EXPR_IS_CHAIN_OFFSET(%r8)
    je codegen_code_chain_leach_expr
    jmp codegen_code_cell_leach_expr

codegen_code_leach_primitive_expr:
    leaq .call_par_code(%rip), %rsi
    movq $CALL_PAR_CODE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    movq LEACH_EXPR_REGION_CHANGES_OFFSET(%r8), %r12
    cmp $0, (%r12)
    jne codegen_code_leach_primitive_expr_region_changes
    jmp codegen_code_leach_primitive_expr_store_primitive

codegen_code_leach_primitive_expr_region_changes:
    movq (%r12), %r11                   # Address of region expression
    movq REGION_EXPR_IDENT_ADDR_OFFSET(%r11), %r11
    call codegen_code_leach_primitive_expr_region_changes_change_region
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    cmp $0, LIST_NEXT(%r12)
    je codegen_code_leach_primitive_expr_store_primitive
    movq LIST_NEXT(%r12), %r12
    jmp codegen_code_leach_primitive_expr_region_changes

codegen_code_leach_primitive_expr_region_changes_change_region:
    cmp $CELLS_REGION, %r11
    je codegen_code_leach_primitive_expr_region_changes_change_to_cells
    leaq .change_region_to_cells_code(%rip), %rsi
    movq $CHANGE_REGION_TO_CELLS_CODE_LEN, %rdx
    call utils_write_file
    ret

codegen_code_leach_primitive_expr_region_changes_change_to_cells:
    leaq .change_region_to_layers_code(%rip), %rsi
    movq $CHANGE_REGION_TO_LAYERS_CODE_LEN, %rdx
    call utils_write_file
    ret

codegen_code_leach_primitive_expr_store_primitive:
    leaq .call_car_code(%rip), %rsi
    movq $CALL_CAR_CODE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    movq PRIMITIVE_EXPR_IDENT_ADDR_OFFSET(%r14), %r13
    cmpb $'!', (%r13)
    je codegen_code_leach_primitive_expr_1
    cmpb $'D', (%r13)
    je codegen_code_leach_primitive_expr_1
    cmpb $'@', (%r13)
    je codegen_code_leach_primitive_expr_2
    cmpb $'C', (%r13)
    je codegen_code_leach_primitive_expr_2
    cmpb $'#', (%r13)
    je codegen_code_leach_primitive_expr_3
    cmpb $'B', (%r13)
    je codegen_code_leach_primitive_expr_3
    cmpb $'+', (%r13)
    je codegen_code_leach_primitive_expr_4
    cmpb $'A', (%r13)
    je codegen_code_leach_primitive_expr_4
    cmpb $'%', (%r13)
    je codegen_code_leach_primitive_expr_5
    cmpb $'9', (%r13)
    je codegen_code_leach_primitive_expr_5
    cmpb $'`', (%r13)
    je codegen_code_leach_primitive_expr_6
    cmpb $'8', (%r13)
    je codegen_code_leach_primitive_expr_6
    cmpb $'&', (%r13)
    je codegen_code_leach_primitive_expr_7
    cmpb $'7', (%r13)
    je codegen_code_leach_primitive_expr_7
    cmpb $'*', (%r13)
    je codegen_code_leach_primitive_expr_8
    cmpb $'6', (%r13)
    je codegen_code_leach_primitive_expr_8
    cmpb $'(', (%r13)
    je codegen_code_leach_primitive_expr_9
    cmpb $'5', (%r13)
    je codegen_code_leach_primitive_expr_9
    cmpb $')', (%r13)
    je codegen_code_leach_primitive_expr_0
    cmpb $'4', (%r13)
    je codegen_code_leach_primitive_expr_0
    cmpb $'<', (%r13)
    je codegen_code_leach_primitive_expr_input
    cmpb $'3', (%r13)
    je codegen_code_leach_primitive_expr_input
    cmpb $'>', (%r13)
    je codegen_code_leach_primitive_expr_output
    cmpb $'2', (%r13)
    je codegen_code_leach_primitive_expr_output
    cmpb $'}', (%r13)
    je codegen_code_leach_primitive_expr_addition
    cmpb $'1', (%r13)
    je codegen_code_leach_primitive_expr_addition
    cmpb $'{', (%r13)
    je codegen_code_leach_primitive_expr_subtraction
    cmpb $'0', (%r13)
    je codegen_code_leach_primitive_expr_subtraction

codegen_code_leach_primitive_expr_1:
    leaq .mov_1(%rip), %rsi
    movq $MOV_1_LEN, %rdx
    jmp codegen_code_leach_primitive_expr_mov

codegen_code_leach_primitive_expr_2:
    leaq .mov_2(%rip), %rsi
    movq $MOV_2_LEN, %rdx
    jmp codegen_code_leach_primitive_expr_mov

codegen_code_leach_primitive_expr_3:
    leaq .mov_3(%rip), %rsi
    movq $MOV_3_LEN, %rdx
    jmp codegen_code_leach_primitive_expr_mov

codegen_code_leach_primitive_expr_4:
    leaq .mov_4(%rip), %rsi
    movq $MOV_4_LEN, %rdx
    jmp codegen_code_leach_primitive_expr_mov

codegen_code_leach_primitive_expr_5:
    leaq .mov_5(%rip), %rsi
    movq $MOV_5_LEN, %rdx
    jmp codegen_code_leach_primitive_expr_mov

codegen_code_leach_primitive_expr_6:
    leaq .mov_6(%rip), %rsi
    movq $MOV_6_LEN, %rdx
    jmp codegen_code_leach_primitive_expr_mov

codegen_code_leach_primitive_expr_7:
    leaq .mov_7(%rip), %rsi
    movq $MOV_7_LEN, %rdx
    jmp codegen_code_leach_primitive_expr_mov

codegen_code_leach_primitive_expr_8:
    leaq .mov_8(%rip), %rsi
    movq $MOV_8_LEN, %rdx
    jmp codegen_code_leach_primitive_expr_mov

codegen_code_leach_primitive_expr_9:
    leaq .mov_9(%rip), %rsi
    movq $MOV_9_LEN, %rdx
    jmp codegen_code_leach_primitive_expr_mov

codegen_code_leach_primitive_expr_0:
    leaq .mov_0(%rip), %rsi
    movq $MOV_0_LEN, %rdx
    jmp codegen_code_leach_primitive_expr_mov

codegen_code_leach_primitive_expr_input:
    leaq .mov_3(%rip), %rsi
    movq $MOV_3_LEN, %rdx
    jmp codegen_code_leach_primitive_expr_mov

codegen_code_leach_primitive_expr_output:
    leaq .mov_2(%rip), %rsi
    movq $MOV_2_LEN, %rdx
    jmp codegen_code_leach_primitive_expr_mov

codegen_code_leach_primitive_expr_addition:
    leaq .mov_1(%rip), %rsi
    movq $MOV_1_LEN, %rdx
    jmp codegen_code_leach_primitive_expr_mov

codegen_code_leach_primitive_expr_subtraction:
    leaq .mov_0(%rip), %rsi
    movq $MOV_0_LEN, %rdx
    jmp codegen_code_leach_primitive_expr_mov

codegen_code_leach_primitive_expr_mov:
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    jmp codegen_code_leach_primitive_expr_store

codegen_code_leach_primitive_expr_store:
    movq LEACH_EXPR_RIGHT_EXPR_OFFSET(%r8), %r13    # Address of right leach expression
    movq LEACH_EXPR_LEFT_EXPR_OFFSET(%r13), %r13    # Right Cell Expression
    movq CELL_EXPR_IDENT_ADDR_OFFSET(%r13), %r15    # Address of cell ident
    cmpb $'A', (%r15)
    jge codegen_code_leach_primitive_store_hex_cell
    movq (%r15), %rsi
    andq $0xff, %rsi
    subq $48, %rsi
    movq %rsi, %r15                         # Storing cell number in %r15 to update TLL table afterwards
    andq $0xff, %r15
    imul $-8, %rsi
    subq $CELLS_OFFSET, %rsi                # Cell offset from base pointer in generated code
    call utils_write_int_file
    jmp codegen_code_leach_primitive_store_end

codegen_code_leach_primitive_store_hex_cell:
    movq (%r15), %rsi
    andq $0xff, %rsi                         # Ascii value of letter
    subq $65, %rsi
    addq $10, %rsi                           # Cell number
    movq %rsi, %r15                          # Storing cell number in %r15 to update TTL table afterwards
    andq $0xff, %r15
    imul $-8, %rsi
    subq $CELLS_OFFSET, %rsi                 # Cell offset from base pointer in generated code
    call utils_write_int_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    jmp codegen_code_leach_primitive_store_end

codegen_code_leach_primitive_store_end:
    leaq .deref_base_pointer(%rip), %rsi
    movq $DEREF_BASE_POINTER_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    imul $-8, %r15
    subq $TTL_OFFSET, %r15
    leaq .mov_num_start(%rip), %rsi
    movq $MOV_NUM_START_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    movq $5, %rsi
    call utils_write_int_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .comma(%rip), %rsi
    movq $COMMA_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    movq %r15, %rsi
    call utils_write_int_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .deref_base_pointer(%rip), %rsi
    movq $DEREF_BASE_POINTER_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    popq %rdx
    popq %rsi
    popq %rdi
    jmp codegen_code_loop_repeat

codegen_code_cell_leach_expr:
    leaq .call_car_code(%rip), %rsi
    movq $CALL_CAR_CODE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    movq LEACH_EXPR_LEFT_EXPR_OFFSET(%r8), %r13     # Address of left cell expression
    movq CELL_EXPR_IDENT_ADDR_OFFSET(%r13), %r13    # Address of cell expression ident
    call codegen_get_cell_number                    # Cell number now in %r14
    movq %r14, %r15                                 # Copy to be used later
    movq %r15, %r12                                 # Copy to be used later

    leaq .mov_num_start(%rip), %rsi
    movq $MOV_NUM_START_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    movq %r14, %rsi
    call utils_write_int_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .comma(%rip), %rsi
    movq $COMMA_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .r15(%rip), %rsi
    movq $R15_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err

    leaq .call_elvr_code(%rip), %rsi
    movq $CALL_ELVR_CODE_LEN, %rdx
    call utils_write_file
    movq LEACH_EXPR_RIGHT_EXPR_OFFSET(%r8), %r13
    movq LEACH_EXPR_LEFT_EXPR_OFFSET(%r13), %r13
    movq CELL_EXPR_IDENT_ADDR_OFFSET(%r13), %r13
    call codegen_get_cell_number                    # Cell number of right cell is now in %r14
    movq %r14, %r9                                  # Cell number to be used later
    leaq .mov_start(%rip), %rsi
    movq $MOV_START_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    imul $-8, %r15
    subq $CELLS_OFFSET, %r15                                 # Cell offset from stack base in generated code
    movq %r15, %rsi
    call utils_write_int_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .deref_base_pointer_no_newline(%rip), %rsi
    movq $DEREF_BASE_POINTER_NO_NEWLINE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .comma(%rip), %rsi
    movq $COMMA_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    
    leaq .r15(%rip), %rsi
    movq $R15_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .newline(%rip), %rsi
    movq $NEWLINE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .mov_start(%rip), %rsi
    movq $MOV_START_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .r15(%rip), %rsi
    movq $R15_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .comma(%rip), %rsi
    movq $COMMA_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err

    imul $-8, %r14
    subq $CELLS_OFFSET, %r14
    movq %r14, %rsi
    call utils_write_int_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .deref_base_pointer(%rip), %rsi
    movq $DEREF_BASE_POINTER_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err

    leaq .mov_num_start(%rip), %rsi
    movq $MOV_NUM_START_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    movq $0, %rsi
    call utils_write_int_file
    leaq .comma(%rip), %rsi
    movq $COMMA_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    imul $-8, %r12
    subq $TTL_OFFSET, %r12
    movq %r12, %rsi
    call utils_write_int_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .deref_base_pointer(%rip), %rsi
    movq $DEREF_BASE_POINTER_LEN, %rdx
    call utils_write_file
    leaq .mov_num_start(%rip), %rsi
    movq $MOV_NUM_START_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    movq $5, %rsi
    call utils_write_int_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .comma(%rip), %rsi
    movq $COMMA_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    movq %r9, %rsi
    imul $-8, %rsi
    subq $TTL_OFFSET, %rsi
    call utils_write_int_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .deref_base_pointer(%rip), %rsi
    movq $DEREF_BASE_POINTER_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err

    popq %rdx
    popq %rsi
    popq %rdi
    jmp codegen_code_loop_repeat

codegen_get_cell_number:
    movq (%r13), %r14
    andq $0xff, %r14
    cmp $'A', %r14
    jge codegen_get_cell_number_hex
    andq $0xff, %r14
    subq $48, %r14
    ret

codegen_get_cell_number_hex:
    subq $65, %r14
    addq $10, %r14
    ret

codegen_code_chain_leach_expr:
    leaq .mov_num_start(%rip), %rsi
    movq $MOV_NUM_START_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    movq CELL_EXPR_IDENT_ADDR_OFFSET(%r14), %r13
    call codegen_get_cell_number
    movq %r14, %rsi
    call utils_write_int_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .comma(%rip), %rsi
    movq $COMMA_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .r15(%rip), %rsi
    movq $R15_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    
    leaq .call_fvr_code(%rip), %rsi
    movq $CALL_FVR_CODE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err

    leaq .args_array_init_code(%rip), %rsi
    movq $ARGS_ARRAY_INIT_CODE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    movq $0, %r12                           # Number of args initialized to 0
    movq %r8, %r15
    jmp codegen_code_chain_leach_expr_args

codegen_code_chain_leach_expr_args:
    movq LEACH_EXPR_RIGHT_EXPR_OFFSET(%r15), %r9
    cmp $0, %r9
    je codegen_code_chain_leach_expr_args_code_push
    movq LEACH_EXPR_LEFT_EXPR_OFFSET(%r9), %r11
    movq CELL_EXPR_IDENT_ADDR_OFFSET(%r11), %r13
    call codegen_get_cell_number                    # Cell number now in %r14
    leaq .push_int_start_code(%rip), %rsi
    movq $PUSH_INT_START_CODE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    movq %r14, %rsi
    call utils_write_int_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .newline(%rip), %rsi
    movq $NEWLINE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    movq %r9, %r15
    incq %r12
    jmp codegen_code_chain_leach_expr_args

codegen_code_chain_leach_expr_args_code_push:
    leaq .mov_num_start(%rip), %rsi
    movq $MOV_NUM_START_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    movq %r12, %rsi
    call utils_write_int_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .comma(%rip), %rsi
    movq $COMMA_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .r13(%rip), %rsi
    movq $R13_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    leaq .newline(%rip), %rsi
    movq $NEWLINE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err

    leaq .call_fer_code(%rip), %rsi
    movq $CALL_FER_CODE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    
    movq $0, %r14
    jmp codegen_code_chain_leach_expr_args_code_pop

codegen_code_chain_leach_expr_args_code_pop:
    cmp %r14, %r12
    je codegen_code_leach_expr_args_end
    leaq .pop_r15_code(%rip), %rsi
    movq $POP_R15_CODE_LEN, %rdx
    call utils_write_file
    cmp $0, %rax
    jl codegen_code_leach_expr_err
    incq %r14
    jmp codegen_code_chain_leach_expr_args_code_pop

codegen_code_leach_expr_args_end:
    popq %rdx
    popq %rsi
    popq %rdi
    jmp codegen_code_loop_repeat

codegen_code_leach_expr_err:
    popq %rax
    popq %rax
    popq %rax
    movq $-1, %rax
    ret