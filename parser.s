# Role
# ----
# Turn a vector of tokens into an expression structure
#
# Expected
# --------
# 1. The address of the tokens is in %rdi
# 2. The length of the tokens is in %rsi
# 2. The address of space for encountered labels in %rdx
# 3. The address of space for encountered jumps in %r10
#
# Result
# ------
# 1. In the case of an error, -1 in %rax, a pointer to the error string in %rdi, the string length in %rsi
# 2. In the case of a success, 0 in %rax, a pointer to the root of the expression structure in %rdi, a 
#    pointer to a vector of strings which represent the labels
#
# Definitions
# -----------
# The Organism Expression is a linked list of Expression structures
# The first byte in each Expression structure is the expression type
# The rest are its fields
# The null expression is a bunch of zeros that take up the space of a single expression
# 
# OrganismExpression        - 1st byte: 1
#                             next 8 bytes: address of child expression
#                             next 8 bytes: null expression or address of next OrganismExpression
#                             next 9 bytes: 0
# JumpExpression            - 1st byte: 2
#                             next 8 bytes: address of label name
#                             next byte: 0 or 1, conditional boolean
#                             next 16 bytes: 0
# LabelExpression           - 1st byte: 3
#                             next 8 bytes: address of label name
#                             next 17 bytes: 0
# DrillExpression           - 1st byte: 4
#                             next 25 bytes: 0
# RegionExpression          - 1st byte: 5
#                             next byte: Region number
#                             next 24 bytes: 0
# LeachExpression           - 1st byte: 6
#                             next 8 bytes: address of expression
#                             next 8 bytes: null expression or address of another leach expression
#                             next byte: 0 or 1, conditional boolean, representing is_chain
#                             next 8 bytes: null (all zeros) or address of an array of region expressions
# PrimitiveExpression       - 1st byte: 7
#                             next 8 bytes: address of primitive number
#                             next 17 bytes: 0
# CellExpression            - 1st byte: 8
#                             next byte: cell identifier
#                             next 24 bytes: 0
# NullExpression            - 1st byte: 0
#                             next 25 bytes: 0
#
# Size of a single expression - 26 bytes
#
# A PrimitiveValue is a number that represents which primitive is being used
# !, D      - 1st byte: 1
# @, C      - 1st byte: 2
# #, B      - 1st byte: 3
# +, A      - 1st byte: 4
# %, 9      - 1st byte: 5
# `, 8      - 1st byte: 6
# &, 7      - 1st byte: 7
# *, 6      - 1st byte: 8
# (, 5      - 1st byte: 9
# ), 4      - 1st byte: 10
# ><, 2     - 1st byte: 11
# <>, 3     - 1st byte: 12
# }, 1      - 1st byte: 13
# {, 0      - 1st byte: 14
#
# A LayersGatesState is a number that represents the state of the gates for compile time checking
# AllClosed, OneOpen, TwoOpen and ThreeOpen are represented by 1, 2, 3, 4 respectively
#
# A Region is a number that represents a region for compile time checking
# Cells and Layers are represented by 1, 2 respectively
#
# Modus Operandi
# --------------
# Go through all tokens 1 by 1, taking notes of the jumps and labels
#
# In the following,
#   %r8 is the current index of the token array
#   %rbx is the current layers gates state
#   %r11 is the current region
#   %r12 is the address of the current OrganismExpression
#   %r15 is the address of the current token
#   %r14 is the length of encountered labels
#   %rbp is the length of the encountered jumps
#
# 1. Calculate the address of the first token addressed by %rdi
# 2. Compare the first byte with 0..=11
# 3. Jump to the block of code for that token type
#
# For Label
# 1. Calculate the address of the location to place the next encountered label
# 2. Place it there
#

.section .data
.err_msg_parser_unimplemented:
    .equ ERR_MSG_PARSER_UNIMPLEMENTED_LEN, 24
    .asciz "Unimplemented for token\n"

.err_msg_drill_in_cells:
    .equ ERR_MSG_DRILL_IN_CELLS_LEN, 68
    .asciz "Attempt to drill while in Cells Region at the nth position. Find n.\n"

.err_msg_attempted_cell_access_in_layers:
    .equ ERR_MSG_ATTEMPTED_CELL_ACCESS_IN_LAYERS_LEN, 64
    .asciz "Attempt to access Cells in Layers Region at position n. Find n.\n"

.err_msg_chained_leach_expr_must_end_in_massacre:
    .equ ERR_MSG_CHAINED_LEACH_EXPR_MUST_END_IN_MASSACRE_LEN, 71
    .asciz "Chain leach expression at position n does not end in massacre. Find n.\n"

.err_msg_attempt_to_leach_expr_onto_itself:
    .equ ERR_MSG_ATTEMPT_TO_LEACH_EXPR_ONTO_ITSELF_LEN, 63
    .asciz "Attempt to leach expression onto itself at position n. Find n.\n"

.err_msg_expected_cell_expr:
    .equ ERR_MSG_EXPECTED_CELL_EXPR_LEN, 48
    .asciz "Cell expression expected at position n. Find n.\n"

.err_msg_leach_expr_must_start_with_primitive_or_cell:
    .equ ERR_MSG_LEACH_EXPR_MUST_START_WITH_PRIMITIVE_OR_CELL_LEN, 74
    .asciz "Leach expression must start with primitive or cell at position n. Find n.\n"

.err_msg_attempted_primitive_access_in_cells:
    .equ ERR_MSG_ATTEMPTED_PRIMITIVE_ACCESS_IN_CELLS_LEN, 67
    .asciz "Attempt to access primitive in Cells Region at position n. Find n.\n"

.err_msg_only_org_expr:
    .equ ERR_MSG_ONLY_ORG_EXPR_LEN, 26
    .asciz "Only Organism expression.\n"

.err_msg_end_of_chain_leach_expr_without_chain_leach_expr:
    .equ ERR_MSG_END_OF_CHAIN_LEACH_EXPR_WITHOUT_CHAIN_LEACH_EXPR_LEN, 94
    .asciz "Ending a chain leach expression without a chain leach expression at the nth position. Find n.\n"

.err_msg_triple_six_eq_not_expected:
    .equ ERR_MSG_TRIPLE_SIX_EQ_NOT_EXPECTED_LEN, 59
    .asciz "^^^^^^666^^^^^^= not expected at the nth position. Find n.\n"

.err_msg_triple_six_not_expected:
    .equ ERR_MSG_TRIPLE_SIX_NOT_EXPECTED_LEN, 59
    .asciz "^^^^^^666^^^^^^ not expected at the nth position. Find n.\n"

.err_msg_jumps_to_non_existent_labels:
    .equ ERR_MSG_JUMPS_TO_NON_EXISTENT_LABELS_LEN, 67
    .asciz "Attempt to jump to non existent label at the nth position. Find n.\n"

.org_expr_repr_start:
    .equ ORG_EXPR_REPR_START_LEN, 19
    .asciz "OrganismExpression("

.org_expr_child_repr_start:
    .equ ORG_EXPR_CHILD_REPR_START_LEN, 7
    .asciz "child: "

.org_expr_child_repr_end:
    .equ ORG_EXPR_CHILD_REPR_END_LEN, 8
    .asciz ", next: "

.org_expr_repr_null:
    .equ ORG_EXPR_REPR_NULL_LEN, 4
    .asciz "null"

.region_expr_repr_start:
    .equ REGION_EXPR_REPR_START_LEN, 21
    .asciz "RegionExpression(to: "

.drill_expr_repr:
    .equ DRILL_EXPR_REPR_LEN, 15
    .asciz "DrillExpression"

.label_expr_repr_start:
    .equ LABEL_EXPR_REPR_START_LEN, 22
    .asciz "LabelExpression(name: "

.jump_expr_repr_start:
    .equ JUMP_EXPR_REPR_START_LEN, 21
    .asciz "JumpExpression(name: "

.jump_expr_cond_field_repr:
    .equ JUMP_EXPR_COND_FIELD_REPR, 19
    .asciz ", conditional: true"

.jump_expr_uncond_field_repr:
    .equ JUMP_EXPR_UNCOND_FIELD_REPR, 20
    .asciz ", conditional: false"

.cell_expr_repr_start:  
    .equ CELL_EXPR_REPR_START_LEN, 22
    .asciz "CellExpression(ident: "

.primitive_expr_repr_start: 
    .equ PRIMITIVE_EXPR_REPR_START_LEN, 27
    .asciz "PrimitiveExpression(ident: "

.leach_expr_repr_start:
    .equ LEACH_EXPR_REPR_START_LEN, 26
    .asciz "LeachExpression(is_chain: "

.leach_expr_is_not_chain_field_repr:
    .equ LEACH_EXPR_IS_NOT_CHAIN_FIELD_REPR_LEN, 7
    .asciz "false, "

.leach_expr_is_chain_field_repr:
    .equ LEACH_EXPR_IS_CHAIN_FIELD_REPR_LEN, 6
    .asciz "true, "

.leach_expr_right_field_repr_start:
    .equ LEACH_EXPR_RIGHT_FIELD_REPR_START_LEN, 9
    .asciz ", right: "

.leach_expr_left_field_repr_start:
    .equ LEACH_EXPR_LEFT_FIELD_REPR_START_LEN, 8
    .asciz ", left: "

.leach_expr_regions_field_repr_start:
    .equ LEACH_EXPR_REGIONS_FIELD_REPR_START_LEN, 10
    .asciz "regions: ["

.leach_expr_regions_field_repr_end:
    .equ LEACH_EXPR_REGIONS_FIELD_REPR_END_LEN, 1
    .asciz "]"

.region_repr_cells:
    .equ REGION_REPR_CELLS_LEN, 5
    .asciz "Cells"

.region_repr_layers:
    .equ REGION_REPR_LAYERS_LEN, 6
    .asciz "Layers"

.leach_expr_repr_end:
.primitive_expr_repr_end:
.cell_expr_repr_end:
.jump_expr_repr_end:
.label_expr_repr_end:
.region_expr_repr_end:
.org_expr_repr_end:
    .equ ORG_EXPR_REPR_END_LEN, 1
    .equ REGION_EXPR_REPR_END_LEN, 1
    .equ LABEL_EXPR_REPR_END_LEN, 1
    .equ JUMP_EXPR_REPR_END_LEN, 1
    .equ CELL_EXPR_REPR_END_LEN, 1
    .equ PRIMITIVE_EXPR_REPR_END_LEN, 1
    .equ LEACH_EXPR_REPR_END_LEN, 1
    .asciz ")"

.print_encountered_labels_header:
    .equ PRINT_ENCOUNTERED_LABELS_HEADER_LEN, 20
    .asciz "Encountered Labels:\n"

.print_encountered_jumps_header:
    .equ PRINT_ENCOUNTERED_JUMPS_HEADER_LEN, 19
    .asciz "Encountered Jumps:\n"

.comma_space:
    .equ COMMA_SPACE_LEN, 2
    .asciz ", "

.equ EXPRESSION_SIZE, 26

.equ ORGANISM_EXPRESSION, 1
.equ JUMP_EXPRESSION, 2
.equ LABEL_EXPRESSION, 3
.equ DRILL_EXPRESSION, 4
.equ REGION_EXPRESSION, 5
.equ LEACH_EXPRESSION, 6
.equ PRIMITIVE_EXPRESSION, 7
.equ CELL_EXPRESSION, 8
.equ NULL_EXPRESSION, 0

.equ CELLS_REGION, 1
.equ LAYERS_REGION, 2

.equ ALL_CLOSED, 1
.equ ONE_OPEN, 2
.equ TWO_OPEN, 3
.equ THREE_OPEN, 4

.equ EXPR_TYPE_OFFSET, 0
.equ ORG_EXPR_CHILD_OFFSET, 1
.equ ORG_EXPR_NEXT_ORG_OFFSET, 9
.equ LABEL_EXPR_NAME_ADDR_OFFSET, 1
.equ JUMP_EXPR_NAME_ADDR_OFFSET, 1
.equ JUMP_EXPR_IS_COND_OFFSET, 9
.equ CELL_EXPR_IDENT_ADDR_OFFSET, 1
.equ LEACH_EXPR_REGION_CHANGES_OFFSET, 18
.equ LEACH_EXPR_IS_CHAIN_OFFSET, 17
.equ LEACH_EXPR_RIGHT_EXPR_OFFSET, 9
.equ LEACH_EXPR_LEFT_EXPR_OFFSET, 1
.equ PRIMITIVE_EXPR_IDENT_ADDR_OFFSET, 1
.equ REGION_EXPR_IDENT_ADDR_OFFSET, 1

.equ UNCONDITIONAL_JUMP, 0
.equ CONDITIONAL_JUMP, 1

.section .text
parser_parse:
    pushq %rdi                          # Save address of tokens
    movq $EXPRESSION_SIZE, %rdi
    call utils_alloc                    # Base Expression structure
    cmp $0, %rax
    jl parser_return
    popq %rdi                           # Restore address of tokens
    movb $ORGANISM_EXPRESSION, (%rax)
    movq $0, ORG_EXPR_NEXT_ORG_OFFSET(%rax)                    # Setting next OrganismExpression field to 0
    pushq %rax                          # Saving the base Expression structure, so it can be restored later
    movq %rax, %r12                     # The current OrganismExpression
    movq $0, %r8                        # The current index of the token array
    movq $CELLS_REGION, %r11            # The current region
    movq $ALL_CLOSED, %rbx              # The current layers gates state
    movq $0, %r14                       # Length of the encountered labels
    movq $0, %rbp                       # Length of the encountered jumps
    cmp $0, %rsi                        # Is the token array empty
    je parser_err_only_org_expr
    jmp parser_parse_loop

parser_parse_loop:
    movq %rdi, %r13                      # The address of the token array
    movq %r8, %r15
    imul $TOKEN_SIZE, %r15               
    addq %rdi, %r15                      # Address of the token at the %r8th index
    movb (%r15), %r9b                    # The token type of the token at the %r8th index
    cmp $REGION_IDENT, %r9b
    je parser_parse_region_ident
    cmp $DRILL, %r9b
    je parser_parse_drill
    cmp $LABEL, %r9b
    je parser_parse_label
    cmp $JUMP, %r9b
    je parser_parse_jump
    cmp $CJUMP, %r9b
    je parser_parse_cond_jump
    cmp $CELL_IDENT, %r9b
    je parser_parse_cell_ident
    cmp $REGION_IDENT, %r9b
    je parser_parse_region_ident
    cmp $TILDE, %r9b
    je parser_err_leach_expr_must_start_with_primitive_or_cell
    cmp $PRIMITIVE_IDENT, %r9b
    je parser_parse_primitive_ident
    cmp $TRIPLE_SIX_EQ_O, %r9b
    je parser_ignore_triple_six_eq_o
    cmp $TRIPLE_SIX_EQ_M, %r9b
    je parser_err_end_of_chain_leach_expr_without_chain_leach_expr
    cmp $TRIPLE_SIX_EQ, %r9b
    je parser_err_triple_six_eq_not_expected
    cmp $TRIPLE_SIX, %r9b
    je parser_err_triple_six_not_expected
    andq $0xff, %r9
    movq %r9, %rdi
    call utils_printint
    jmp parser_unimplemented

parser_parse_loop_repeat:
    incq %r8                            # Increase the current index of the token array
    cmp %r8, %rsi                       # Have all the tokens been checked
    je parser_parse_loop_end
    pushq %r8
    pushq %rdi
    pushq %r11
    call utils_alloc
    cmp $0, %rax
    popq %r11
    popq %rdi
    popq %r8
    jl parser_parse_loop_repeat_err_alloc
    movq $0, ORG_EXPR_NEXT_ORG_OFFSET(%rax)         # Setting the next OrganismExpression field to 0
    movq %rax, ORG_EXPR_NEXT_ORG_OFFSET(%r12)       # Storing the newly created OrganismExpression address in the next OrganismExpression field
    movq %rax, %r12                     # Setting the newly created OrganismExpression address to be the current OrganismExpression
    jmp parser_parse_loop

parser_parse_loop_repeat_err_alloc:
    popq %rbx
    popq %rbx
    ret

parser_parse_loop_end:
    pushq %r12                                  # Save the current OrganismExpression
    movq $EXPRESSION_SIZE, %rdi
    call utils_alloc
    jl parser_parse_loop_end_err_alloc
    movb $NULL_EXPRESSION, (%rax)
    popq %r12
    movq %rax, ORG_EXPR_NEXT_ORG_OFFSET(%r12)   # Setting the last OrganismExpression's next to the null expression
    call parser_check_if_all_jumps_exist
    cmp $0, %rax
    je parser_err_jumps_to_non_existent_labels
    call parser_print_encountered_labels
    call parser_print_encountered_jumps
    popq %rax                                   # The address of the base OrganismExpression pushed in the beginning
    call parser_print_org_expr
    ret

parser_check_if_all_jumps_exist:
    movq $0, %r8                    # Initialize jump array index to 0
    movq $1, %rax                   # Initialize result to true
    jmp parser_check_if_all_jumps_exist_loop

parser_check_if_all_jumps_exist_loop:
    cmp %r8, %rbp                           # Have all the jumps being processed?
    je parser_return
    movq %r8, %r15
    imul $8, %r15
    addq %r10, %r15                     
    movq (%r15), %r15                   # Address of current jump
    movq $0, %r9                        # Initialize label array index to 0
    movq $0, %rbx                       # Initialize current_jump_is_found to false
    jmp parser_check_if_all_jumps_exist_inner_loop

parser_check_if_all_jumps_exist_inner_loop:
    cmp %r9, %r14                       # Have all the loops been processed?
    je parser_check_if_all_jumps_exist_inner_loop_end_fail
    movq %r9, %r13
    imul $8, %r13
    addq %rdx, %r13                      
    movq (%r13), %r13                   # Address of current encountered label
    movq %r15, %rdi
    movq %r13, %rsi
    call utils_streq
    cmp $1, %rax
    je parser_check_if_all_jumps_exist_inner_loop_end_success
    incq %r9
    jmp parser_check_if_all_jumps_exist_inner_loop

parser_check_if_all_jumps_exist_inner_loop_end_success:
    incq %r8
    jmp parser_check_if_all_jumps_exist_loop

parser_check_if_all_jumps_exist_inner_loop_end_fail:
    movq $0, %rax
    ret

parser_check_if_all_jumps_exist_loop_end:
    ret

parser_parse_loop_end_err_alloc:
    popq %rbx           # Pop off pushed values
    popq %rbx           # Pop off address of base OrganismExpression
    ret                 # Return utils_alloc error

parser_ignore_triple_six_eq_o:
    incq %r8
    cmp %r8, %rsi
    je parser_parse_loop_end
    jmp parser_parse_loop

parser_parse_region_ident:
    movq TOKEN_STRING_ADDR_OFFSET(%r15), %rcx     # Address of the region identifier
    cmpb $'L', (%rcx)
    je parser_parse_region_ident_change_to_layers
    jmp parser_parse_region_ident_change_to_cells

parser_parse_drill:
    cmp $LAYERS_REGION, %r11
    jne parser_err_drill_in_cells
    cmp $THREE_OPEN, %rbx
    je parser_parse_drill_append_expression
    incq %rbx
    jmp parser_parse_drill_append_expression

parser_parse_label:
    movq TOKEN_STRING_ADDR_OFFSET(%r15), %r13       # Address of the label name
    call parser_append_encountered_label
    jmp parser_parse_label_append_expression

parser_parse_jump:
    movq TOKEN_STRING_ADDR_OFFSET(%r15), %r13
    call parser_append_encountered_jump
    pushq %r9
    movq $UNCONDITIONAL_JUMP, %r9
    jmp parser_parse_jump_append_expression

parser_parse_cond_jump:
    movq TOKEN_STRING_ADDR_OFFSET(%r15), %r13
    call parser_append_encountered_jump
    pushq %r9
    movq $CONDITIONAL_JUMP, %r9
    jmp parser_parse_jump_append_expression

parser_parse_primitive_ident:
    cmp $LAYERS_REGION, %r11
    jne parser_err_attempted_primitive_access_in_cells
    movq %r8, %r9
    jmp parser_parse_primitive_ident_check_through_regions

parser_parse_primitive_ident_check_through_regions:
    incq %r9
    cmp %r9, %rsi
    je parser_parse_primitive_ident_not_leach_expr
    movq %r9, %r13
    imul $TOKEN_SIZE, %r13
    addq %rdi, %r13
    cmpb $REGION_IDENT, (%r13)
    je parser_parse_primitive_ident_check_through_regions
    cmpb $TILDE, (%r13)
    je parser_parse_primitive_leach_expr
    jmp parser_parse_primitive_ident_not_leach_expr

parser_parse_primitive_leach_expr:
    .equ LIST_NODE_SIZE, 16             # Size of a single node in the region changes list
    .equ LIST_NEXT, 8
    movq %r8, %r9                       # Reset %r9 to index of current token
    pushq %rcx                          # Save whatever was in %rcx
    pushq %r14
    pushq %r12
    pushq %rdi
    movq $LIST_NODE_SIZE, %rdi
    call utils_alloc
    cmp $0, %rax
    jl parser_parse_primitive_leach_expr_return_err
    movq %rax, %rcx                     # Head of the region changes singly linked null terminated list
    movq $0, (%rcx)                     # Initialize address of region to 0
    movq $0, LIST_NEXT(%rcx)            # Initialize address of next node to 0
    popq %rdi
    call parser_parse_primitive_leach_expr_region_changes
    pushq %rdi
    movq %r8, %r15
    imul $TOKEN_SIZE, %r15
    popq %rdi
    addq %rdi, %r15
    pushq %rdi
    movq $EXPRESSION_SIZE, %rdi
    call utils_alloc
    jl parser_parse_primitive_leach_expr_return_err
    movq %rax, %r12                     # Space for the primitive expression
    movb $PRIMITIVE_EXPRESSION, (%r12)
    movq TOKEN_STRING_ADDR_OFFSET(%r15), %r13
    movq %r13, PRIMITIVE_EXPR_IDENT_ADDR_OFFSET(%r12)
    movq %r9, %r8                       # Update current token index to index right after region expressions
    incq %r8                            # Jump the tilde
    movq %r8, %r15
    imul $TOKEN_SIZE, %r15
    popq %rdi
    addq %rdi, %r15
    pushq %rdi
    cmpb $CELL_IDENT, (%r15)
    jne parser_parse_primitive_leach_expr_err_expected_cell_expr
    cmpb $CELLS_REGION, %r11b
    jne parser_parse_primitive_leach_expr_err_attempted_cell_access_in_layers
    movq $EXPRESSION_SIZE, %rdi
    call utils_alloc                    # Space for the cell expression
    cmp $0, %rax
    jl parser_parse_primitive_leach_expr_return_err
    movb $CELL_EXPRESSION, (%rax)
    movq TOKEN_STRING_ADDR_OFFSET(%r15), %r13
    movq %r13, CELL_EXPR_IDENT_ADDR_OFFSET(%rax)
    movq %rax, %r14                     # The newly created cell expression
    movq $EXPRESSION_SIZE, %rdi
    call utils_alloc
    movb $LEACH_EXPRESSION, (%rax)      # The right leach expression
    movq %r14, LEACH_EXPR_LEFT_EXPR_OFFSET(%rax)
    movq $0, LEACH_EXPR_RIGHT_EXPR_OFFSET(%rax)
    movb $0, LEACH_EXPR_IS_CHAIN_OFFSET(%rax)
    movq $0, LEACH_EXPR_REGION_CHANGES_OFFSET(%rax)
    movq %rax, %r14                     # The right leach expression
    movq $EXPRESSION_SIZE, %rdi
    call utils_alloc
    cmp $0, %rax
    jl parser_parse_primitive_leach_expr_return_err
    movb $LEACH_EXPRESSION, (%rax)
    movq %r12, LEACH_EXPR_LEFT_EXPR_OFFSET(%rax)     # The primitive expression
    movq %r14, LEACH_EXPR_RIGHT_EXPR_OFFSET(%rax)    # The right leach expression
    movb $0, LEACH_EXPR_IS_CHAIN_OFFSET(%rax)
    movq %rcx, LEACH_EXPR_REGION_CHANGES_OFFSET(%rax)
    popq %rdi
    popq %r12
    popq %r14
    popq %rcx
    pushq %r14
    call parser_calc_org_expr_child_addr
    movq %rax, (%r14)
    popq %r14
    jmp parser_parse_loop_repeat

parser_parse_primitive_leach_expr_err_expected_cell_expr:
    popq %rdi
    popq %r12
    popq %r14
    popq %rcx
    jmp parser_err_expected_cell_expr

parser_parse_primitive_leach_expr_err_attempted_cell_access_in_layers:
    popq %rdi
    popq %r12
    popq %r14
    popq %rcx
    jmp parser_err_attempted_cell_access_in_layers

parser_parse_primitive_leach_expr_region_changes:
    # Check if the next token is a region change
    # If it is, create a region change expression, append it and repeat
    # It it isn't return
    incq %r9
    movq %r9, %r15
    imul $TOKEN_SIZE, %r15
    addq %rdi, %r15             # Address of next token
    cmpb $REGION_IDENT, (%r15)
    jne parser_return
    call parser_parse_primitive_leach_expr_region_changes_change_region
    cmp $0, (%rcx)              # Is the list empty?
    je parser_parse_primitive_leach_expr_region_changes_insert_head
    jmp parser_parse_primitive_leach_expr_region_changes_insert

parser_parse_primitive_leach_expr_region_changes_change_region:
    movq TOKEN_STRING_ADDR_OFFSET(%r15), %r13
    cmpb $'C', (%r13)
    je parser_parse_primitive_leach_expr_region_changes_change_region_cells
    jmp parser_parse_primitive_leach_expr_region_changes_change_region_layers

parser_parse_primitive_leach_expr_region_changes_change_region_cells:
    movq $CELLS_REGION, %r11
    ret

parser_parse_primitive_leach_expr_region_changes_change_region_layers:
    movq $LAYERS_REGION, %r11
    ret

parser_parse_primitive_leach_expr_region_changes_insert_head:
    pushq %rdi
    movq $EXPRESSION_SIZE, %rdi
    call utils_alloc
    cmp $0, %rax
    jl parser_parse_primitive_leach_expr_region_changes_insert_head_return_err
    movb $REGION_EXPRESSION, (%rax)
    movq TOKEN_STRING_ADDR_OFFSET(%r15), %r13
    movq %r13, REGION_EXPR_IDENT_ADDR_OFFSET(%rax)
    movq %rax, %r13                     # The newly created region expression
    movq $LIST_NODE_SIZE, %rdi
    call utils_alloc
    cmp $0, %rax
    jl parser_parse_primitive_leach_expr_region_changes_insert_head_return_err
    movq %rax, %rcx
    movq $0, LIST_NEXT(%rcx)
    movq %r13, (%rcx)
    popq %rdi
    jmp parser_parse_primitive_leach_expr_region_changes

parser_parse_primitive_leach_expr_region_changes_insert_head_return_err:
    popq %rdi
    ret

# Inserts the expressions in reverse order
parser_parse_primitive_leach_expr_region_changes_insert:
    pushq %rdi
    pushq %r14
    movq $EXPRESSION_SIZE, %rdi
    call utils_alloc
    cmp $0, %rax
    jl parser_parse_primitive_leach_expr_region_changes_insert_return_err
    movb $REGION_EXPRESSION, (%rax)
    movq TOKEN_STRING_ADDR_OFFSET(%r15), %r13
    movq %r13, REGION_EXPR_IDENT_ADDR_OFFSET(%rax)
    movq %rax, %r13                             # The newly created region expression
    movq $LIST_NODE_SIZE, %rdi
    call utils_alloc
    jl parser_parse_primitive_leach_expr_region_changes_insert_return_err
    movq %r13, (%rax)
    movq %rcx, LIST_NEXT(%rax)
    movq %rax, %rcx
    popq %r14
    popq %rdi
    jmp parser_parse_primitive_leach_expr_region_changes

parser_parse_primitive_leach_expr_region_changes_insert_return_err:
    popq %r14
    popq %rdi
    ret

parser_parse_primitive_leach_expr_return_err:
    popq %rdi
    popq %r12
    popq %r14
    popq %rcx
    ret

parser_parse_primitive_ident_not_leach_expr:
    pushq %rdi
    movq %r8, %r9
    movq $EXPRESSION_SIZE, %rdi
    call utils_alloc
    cmp $0, %rax
    jl parser_parse_primitive_ident_not_leach_expr_alloc_err
    movb $PRIMITIVE_EXPRESSION, (%rax)
    movq TOKEN_STRING_ADDR_OFFSET(%r15), %r13
    movq %r13, PRIMITIVE_EXPR_IDENT_ADDR_OFFSET(%rax)
    pushq %r14
    call parser_calc_org_expr_child_addr
    movq %rax, (%r14)
    popq %r14
    popq %rdi
    jmp parser_parse_loop_repeat

parser_parse_primitive_ident_not_leach_expr_alloc_err:
    popq %rdi
    ret

parser_parse_cell_ident:
    cmp $CELLS_REGION, %r11
    jne parser_err_attempted_cell_access_in_layers
    movq %r8, %r9
    incq %r9
    cmp %r9, %rsi
    je parser_parse_cell_ident_append_expression    # If this is the last token, append expression
    imul $TOKEN_SIZE, %r9
    addq %rdi, %r9                                  # Calculate the address of the next token
    cmp $TILDE, (%r9)                               # Is the next token a tilde?
    je parser_parse_cell_leach_expression
    jmp parser_parse_cell_ident_append_expression

parser_parse_cell_leach_expression:
    .equ LIST_NEXT, 8                       # The offset of the next field in a linked list node
    .equ LIST_NODE_SIZE, 16                 # The size of a single node in the linked lists
    .equ TOKEN_ARRAY_BASE_ADDR, 56          # The stack offset of the token base address
    .equ TOKEN_ARRAY_LEN, 48                # The stack offset of the token array length
    pushq %rbx
    pushq %rdi
    pushq %rsi
    pushq %rax
    pushq %r10
    pushq %r14
    pushq %rcx
    pushq %r11
    pushq %rbp
    movq %rsp, %rbp
    movq $EXPRESSION_SIZE, %rdi
    call utils_alloc
    jl parser_parse_cell_leach_expression_return_err                                    # For now
    movb $CELL_EXPRESSION, (%rax)
    movq TOKEN_STRING_ADDR_OFFSET(%r15), %r13
    movq %r13, CELL_EXPR_IDENT_ADDR_OFFSET(%rax)        # Create CellExpression
    movq $0, %r14                                       # Is the predecessor a chained leach expression
    movq %rax, %r11                                     # The current left cell expression
    movq $LIST_NODE_SIZE, %rax                          # Space for 2 addresses
    call utils_alloc
    cmp $0, %rax
    jl parser_parse_cell_leach_expression_return_err    # For now
    movq %rax, %rbx                                     # Address of head of cells encountered circular linked list
    movq $0, (%rbx)                                     # Init value to 0
    movq $0, LIST_NEXT(%rbx)                            # Init next to 0
    movq %r15, %r9
    call parser_parse_leach_insert_cells_encountered
    movq $LIST_NODE_SIZE, %rax                          # Space for 2 addresses
    call utils_alloc
    cmp $0, %rax
    jl parser_parse_cell_leach_expression_return_err    # For now
    movq %rax, %rcx                                     # Address of head of region changes linked list
    movq $0, (%rcx)                                     # Init to 0
    movq $0, LIST_NEXT(%rcx)                            # Init next to 0
    incq %r8                                            # Increase token array index to the tilde
    call parser_parse_cell_leach_expression_loop
    cmp $0, %rax
    jl parser_parse_cell_leach_expression_return_err
    popq %rbp
    popq %r11
    popq %rcx
    popq %r14
    popq %r10
    popq %rax
    popq %rsi
    popq %rdi
    # %rbx is to be popped in the next code block
    jmp parser_parse_cell_leach_append_expression

parser_parse_cell_leach_expression_return_err:
    popq %rbp
    popq %r11
    popq %rcx
    popq %r14
    popq %r10
    popq %r10
    popq %r10
    popq %r10
    popq %rbx
    popq %rbx
    ret

parser_parse_cell_leach_expression_loop:
    movq %r8, %r9
    incq %r9                                    # Index of next token
    cmp %r9, TOKEN_ARRAY_LEN(%rbp)              # Is the current token the last token?
    je parser_parse_leach_expr_err_expected_cell_expr # If this is the last token, return an error
    incq %r8                                    # Move to next token, because tilde is not needed
    movq %r8, %r9
    imul $TOKEN_SIZE, %r9
    addq TOKEN_ARRAY_BASE_ADDR(%rbp), %r9       # Calculated address of token after the tilde
    cmpb $CELL_IDENT, (%r9)                     # Is this token a cell ident
    jne parser_parse_cell_leach_expr_loop_err_expected_cell_expr    # If it's not, return an error
    call parser_parse_cell_leach_encountered_cells_contains_cell    # Is the current cell in the cells encountered list?
    cmp $0, %rax                                # 0 means false, it's not there
    jne parser_parse_cell_leach_expr_loop_err_attempt_to_leach_expr_onto_itself
    call parser_parse_leach_insert_cells_encountered
    cmp $0, %rax
    jne parser_return
    movq %r9, %r15                              # Address of current token in token array
    movq %r8, %r9                               # Index of current token in token array
    incq %r9                                    # Index of next token
    cmp %r9, TOKEN_ARRAY_LEN(%rbp)              # Is the current token the last token?
    je parser_parse_leach_expression_loop_end
    incq %r8                                    # Increase index of token array
    imul $TOKEN_SIZE, %r9
    addq TOKEN_ARRAY_BASE_ADDR(%rbp), %r9       # Address of current token in token array
    cmpb $TILDE, (%r9)
    je parser_parse_cell_leach_expression_chain
    cmpb $TRIPLE_SIX_EQ_M, (%r9)
    je parser_parse_cell_leach_expression_chain_end
    jmp parser_parse_leach_expression_loop_end

parser_parse_cell_leach_expr_loop_err_expected_cell_expr:
    leaq .err_msg_expected_cell_expr(%rip), %rdi
    movq $ERR_MSG_EXPECTED_CELL_EXPR_LEN, %rsi
    movq $-1, %rax
    ret

parser_parse_cell_leach_expr_loop_err_attempt_to_leach_expr_onto_itself:
    leaq .err_msg_attempt_to_leach_expr_onto_itself(%rip), %rdi
    movq $ERR_MSG_ATTEMPT_TO_LEACH_EXPR_ONTO_ITSELF_LEN, %rsi
    movq $-1, %rax
    ret

parser_parse_cell_leach_expression_chain:
    movq %r8, %r9
    incq %r9                                # Increase index of token array
    cmp TOKEN_ARRAY_LEN(%rbp), %r9          # Is this the last token
    je parser_parse_cell_leach_expr_chain_err_expected_cell_expr1
    pushq %r11
    pushq $1                                # Set is chain to true
    pushq %r15                              # Address of current token
    pushq %rcx                              # Region changes list
    imul $TOKEN_SIZE, %r9
    addq TOKEN_ARRAY_BASE_ADDR(%rbp), %r9
    cmpb $CELL_IDENT, (%r9)
    jne parser_parse_cell_leach_expr_chain_err_expected_cell_expr2
    call parser_parse_cell_leach_encountered_cells_contains_cell    # Is the current cell in the cells encountered list?
    cmp $0, %rax                            # 0 means false, it's not there
    jne parser_parse_cell_leach_expression_chain_self_leach
    movq $EXPRESSION_SIZE, %rdi
    call utils_alloc
    cmp $0, %rax
    jl parser_parse_cell_leach_expression_chain_return_err
    movq %rax, %r11                         # The address of left cell expression in the next call
    movb $CELL_EXPRESSION, (%r11)           # Create the cell expression 
    movq TOKEN_STRING_ADDR_OFFSET(%r15), %r13
    movq %r13, CELL_EXPR_IDENT_ADDR_OFFSET(%r11)
    movq $LIST_NODE_SIZE, %rdi              # Space for the next call's region changes
    call utils_alloc
    cmp $0, %rax
    jl parser_parse_cell_leach_expression_chain_return_err
    movq %rax, %rcx                         # The new region changes list
    movq $0, (%rcx)
    movq $0, LIST_NEXT(%rcx)
    movq $1, %r14                           # The predecessor is chained
    call parser_parse_cell_leach_expression_loop
    cmp $0, %rax
    jne parser_parse_cell_leach_expression_chain_return_err
    popq %rcx
    popq %r15
    popq %r14
    popq %r11
    cmp $0, %rax
    jne parser_return
    movq $EXPRESSION_SIZE, %rdi
    call utils_alloc
    cmp $0, %rax
    jl parser_return
    movb $LEACH_EXPRESSION, (%rax)
    movq %r11, LEACH_EXPR_LEFT_EXPR_OFFSET(%rax)
    movq %rbx, LEACH_EXPR_RIGHT_EXPR_OFFSET(%rax)
    movb %r14b, LEACH_EXPR_IS_CHAIN_OFFSET(%rax)
    movq $0, LEACH_EXPR_REGION_CHANGES_OFFSET(%rax)
    movq $0, %rbx
    xchg %rax, %rbx
    ret

parser_parse_cell_leach_expr_chain_err_expected_cell_expr1:
    leaq .err_msg_expected_cell_expr(%rip), %rdi
    movq $ERR_MSG_EXPECTED_CELL_EXPR_LEN, %rsi
    movq $-1, %rax
    ret

parser_parse_cell_leach_expr_chain_err_expected_cell_expr2:
    popq %rbx
    popq %rbx
    popq %rbx
    popq %rbx
    jmp parser_parse_cell_leach_expr_chain_err_expected_cell_expr1

parser_parse_cell_leach_expression_chain_end:
    not %r14
    and $0x1, %r14
    jmp parser_parse_leach_expression_append_last_cell_expression

parser_parse_leach_expression_loop_end:
    cmp $0, %r14                                # Is the this supposed to be a chained leach expression
    jne parser_parse_leach_expression_loop_end_err_massacre
    jmp parser_parse_leach_expression_append_last_cell_expression

parser_parse_leach_expression_append_last_cell_expression:
    pushq %rdx
    movq $EXPRESSION_SIZE, %rdi
    call utils_alloc
    jl parser_parse_leach_expr_append_last_cell_expr_return_err
    movb $LEACH_EXPRESSION, (%rax)
    movq %r11, LEACH_EXPR_LEFT_EXPR_OFFSET(%rax)
    movq %rax, %rbx
    movq $EXPRESSION_SIZE, %rdi
    call utils_alloc                            # Space for right leach expression
    cmp $0, %rax
    jl parser_parse_leach_expr_append_last_cell_expr_return_err
    movq %rax, %rdx                             # Right leach expression
    movq $EXPRESSION_SIZE, %rdi
    call utils_alloc
    cmp $0, %rax
    jl parser_parse_leach_expr_append_last_cell_expr_return_err
    movb $CELL_EXPRESSION, (%rax)
    movq TOKEN_STRING_ADDR_OFFSET(%r15), %r13
    movq %r13, CELL_EXPR_IDENT_ADDR_OFFSET(%rax)
    movq %rax, LEACH_EXPR_LEFT_EXPR_OFFSET(%rdx)
    movq $0, LEACH_EXPR_RIGHT_EXPR_OFFSET(%rdx)
    movb $0, LEACH_EXPR_IS_CHAIN_OFFSET(%rdx)
    movq $0, LEACH_EXPR_REGION_CHANGES_OFFSET(%rdx)
    movq %rdx, LEACH_EXPR_RIGHT_EXPR_OFFSET(%rbx)
    movb %r14b, LEACH_EXPR_IS_CHAIN_OFFSET(%rbx)
    movq $0, LEACH_EXPR_REGION_CHANGES_OFFSET(%rbx)     # The leach expression pointed to by %rbx now fully created
    movq $0, %rax                               # Successful result
    popq %rdx
    ret

parser_parse_leach_expr_append_last_cell_expr_return_err:
    popq %rdx
    ret

parser_parse_leach_insert_cells_encountered:
    # Allocate space for a node
    # Copy the value of the list head's next field into the node's next field
    # Copy the address of the new node into the list head's next field
    # Copy the address of the string of the cell ident into the value field of that node
    cmp $0, (%rbx)              # Is the list empty?
    je parser_parse_leach_insert_cells_encountered_head
    movq $LIST_NODE_SIZE, %rdi
    call utils_alloc
    cmp $0, %rax
    jl parser_return
    movq LIST_NEXT(%rbx), %r13
    movq %r13, LIST_NEXT(%rax)
    movq %rax, LIST_NEXT(%rbx)
    movq TOKEN_STRING_ADDR_OFFSET(%r9), %r13
    movq %r13, (%rax)
    movq $0, %rax
    ret

parser_parse_leach_insert_cells_encountered_head:
    movq $LIST_NODE_SIZE, %rdi
    call utils_alloc
    cmp $0, %rax
    jl parser_return
    movq TOKEN_STRING_ADDR_OFFSET(%r9), %r13
    movq %r13, (%rax)
    movq %rax, LIST_NEXT(%rax)
    movq %rax, %rbx
    movq $0, %rax
    ret

parser_parse_cell_leach_encountered_cells_contains_cell:
    # Save value of current cells encountered list in a register
    # Compare the address of the next field with 0
    # If it's 0, then the list is empty, return
    # Follow the address of the next field to another node
    # Compare the values of the address field in the first and second node
    # If they are the same, return 0
    # If they are not the same, save the value of the head, assign the current node to the head and repeat
    movq $0, %rax               # Initialize return value to false
    cmp $0, LIST_NEXT(%rbx)     # If it's 0, the list is empty
    je parser_return
    movq %rbx, %rdi             # Initialize current node to root
    movq CELL_EXPR_IDENT_ADDR_OFFSET(%r9), %r10  # The address of the cell ident
    call parser_parse_cell_leach_encountered_cells_contains_cell_loop
    ret

parser_parse_cell_leach_encountered_cells_contains_cell_loop:
    movb (%r10), %r13b           # The value of the first character in the cell ident
    movq (%rdi), %rsi            # The address of the cell ident in node
    cmpb (%rsi), %r13b           # Are the cell idents equal?
    je parser_parse_cell_leach_encountered_cells_contains_cell_loop_end_found_ident
    cmp LIST_NEXT(%rdi), %rbx    # Is the search over
    je parser_return
    movq LIST_NEXT(%rdi), %rdi
    call parser_parse_cell_leach_encountered_cells_contains_cell_loop
    ret

parser_parse_cell_leach_encountered_cells_contains_cell_loop_end_found_ident:
    movq $1, %rax
    ret

parser_parse_leach_expr_err_expected_cell_expr:
    popq %rbp
    popq %r11
    popq %rcx
    popq %r14
    popq %r10
    popq %rax
    popq %rsi
    popq %rdi
    popq %rbx
    jmp parser_err_expected_cell_expr

parser_parse_cell_leach_expression_chain_self_leach:
    popq %rax
    popq %rax
    popq %rax
    popq %rax
    movq $-1, %rax
    leaq .err_msg_attempt_to_leach_expr_onto_itself, %rdi
    movq $ERR_MSG_ATTEMPT_TO_LEACH_EXPR_ONTO_ITSELF_LEN, %rsi
    ret

parser_parse_leach_expression_loop_end_err_massacre:
    movq $-1, %rax
    leaq .err_msg_chained_leach_expr_must_end_in_massacre(%rip), %rdi
    movq $ERR_MSG_CHAINED_LEACH_EXPR_MUST_END_IN_MASSACRE_LEN, %rsi
    ret

parser_parse_cell_leach_expression_chain_return_err:
    popq %rax
    popq %rax
    popq %rax
    popq %rax
    movq $-1, %rax
    ret

parser_parse_cell_leach_expression_err_alloc:
    popq %rbx
    popq %rbx
    ret

parser_parse_org_death:
    jmp parser_parse_loop_end

parser_parse_region_ident_change_to_cells:
    movq $CELLS_REGION, %r11
    jmp parser_parse_region_ident_append_expression

parser_parse_region_ident_change_to_layers:
    movq $LAYERS_REGION, %r11
    jmp parser_parse_region_ident_append_expression

parser_parse_region_ident_append_expression:
    pushq %rdi
    pushq %r14
    movq $EXPRESSION_SIZE, %rdi
    pushq %rax
    pushq %r8
    pushq %r11
    call utils_alloc
    cmp $0, %rax                            # %rax should now contain the base address of the RegionExpression
    jl parser_return
    movb $REGION_EXPRESSION, (%rax)
    popq %r11
    movq %r11, REGION_EXPR_IDENT_ADDR_OFFSET(%rax)   # Region number
    call parser_calc_org_expr_child_addr
    movq %rax, (%r14)                         # Storing address of Region Expression in current OrganismExpression child location
    popq %r8
    popq %rax
    popq %r14
    popq %rdi
    jmp parser_parse_loop_repeat

parser_parse_drill_append_expression:
    pushq %r14
    pushq %rdi
    movq $EXPRESSION_SIZE, %rdi
    pushq %rax
    call utils_alloc
    cmp $0, %rax
    jl parser_return
    movb $DRILL_EXPRESSION, (%rax)
    call parser_calc_org_expr_child_addr
    movq %rax, (%r14)
    popq %rax
    popq %rdi
    popq %r14
    jmp parser_parse_loop_repeat

parser_parse_label_append_expression:
    pushq %rdi
    pushq %r13
    pushq %r14
    movq $EXPRESSION_SIZE, %rdi
    pushq %rax
    call utils_alloc
    cmp $0, %rax
    jl parser_parse_label_append_expression_err_alloc
    movb $LABEL_EXPRESSION, (%rax)
    movq TOKEN_STRING_ADDR_OFFSET(%r15), %r13
    movq %r13, LABEL_EXPR_NAME_ADDR_OFFSET(%rax)
    call parser_calc_org_expr_child_addr
    movq %rax, (%r14)
    popq %rax
    popq %r14
    popq %r13
    popq %rdi
    jmp parser_parse_loop_repeat

parser_parse_jump_append_expression:
    pushq %rdi
    pushq %r13
    pushq %r14
    movq $EXPRESSION_SIZE, %rdi
    pushq %rax
    call utils_alloc
    cmp $0, %rax
    jl parser_parse_jump_append_expression_err_alloc
    movb $JUMP_EXPRESSION, (%rax)
    movq TOKEN_STRING_ADDR_OFFSET(%r15), %r13
    movq %r13, JUMP_EXPR_NAME_ADDR_OFFSET(%rax)
    movb %r9b, JUMP_EXPR_IS_COND_OFFSET(%rax)
    call parser_calc_org_expr_child_addr
    movq %rax, (%r14)
    popq %rax
    popq %r14
    popq %r13
    popq %rdi
    popq %r9
    jmp parser_parse_loop_repeat

parser_parse_cell_ident_append_expression:
    pushq %rdi
    pushq %r14
    movq $EXPRESSION_SIZE, %rdi
    pushq %rax
    call utils_alloc
    cmp $0, %rax
    jl parser_parse_cell_ident_append_expression_err_alloc
    movb $CELL_EXPRESSION, (%rax)
    pushq %r13
    movq TOKEN_STRING_ADDR_OFFSET(%r15), %r13
    movq %r13, CELL_EXPR_IDENT_ADDR_OFFSET(%rax)
    popq %r13
    call parser_calc_org_expr_child_addr
    movq %rax, (%r14)
    popq %rax
    popq %r14
    popq %rdi
    jmp parser_parse_loop_repeat

parser_parse_cell_leach_append_expression:
    pushq %r14
    call parser_calc_org_expr_child_addr
    movq %rbx, (%r14)                       # Moving the newly created leach expression into the child slot of the current org expr    
    popq %r14
    popq %rbx
    jmp parser_parse_loop_repeat

parser_parse_label_append_expression_err_alloc:
    popq %rbx       # Pop off pushed stack values
    popq %rbx
    popq %rbx
    popq %rbx
    popq %rbx       # Pop off base OrganismExpression address
    ret             # Return utils_alloc error

parser_parse_jump_append_expression_err_alloc:
    popq %rbx       # Pop off pushed stack values
    popq %rbx
    popq %rbx
    popq %rbx
    popq %rbx
    popq %rbx       # Pop off base OrganismExpression address
    ret             # Return utils_alloc error

parser_parse_cell_ident_append_expression_err_alloc:
    popq %rbx
    popq %rbx
    popq %rbx
    popq %rbx
    ret

parser_calc_org_expr_child_addr:
    movq %r12, %r14                 # Address of current OrganismExpression
    incq %r14                       # Address of location to store child expression
    ret

parser_append_encountered_label:
    pushq %r12
    pushq %r15
    movq %rdx, %r12
    movq %r14, %r15
    imul $8, %r15
    addq %r15, %r12             # Calculate address to place label name in encountered labels array
    movq %r13, (%r12)           # Store address of label name at end of encountered labels array
    incq %r14                   # Increase length by 1
    popq %r15
    popq %r12
    ret

parser_append_encountered_jump:
    pushq %r12
    pushq %r15
    movq %r10, %r12
    movq %rbp, %r15
    imul $8, %r15
    addq %r15, %r12
    movq %r13, (%r12)
    incq %rbp
    popq %r15
    popq %r12
    ret

parser_return:
    ret

parser_unimplemented:
    leaq .err_msg_parser_unimplemented(%rip), %rdi
    movq $ERR_MSG_PARSER_UNIMPLEMENTED_LEN, %rsi
    popq %rax
    movq $-1, %rax
    ret

parser_err_drill_in_cells:
    leaq .err_msg_drill_in_cells(%rip), %rdi
    movq $ERR_MSG_DRILL_IN_CELLS_LEN, %rsi
    popq %rax
    movq $-1, %rax
    ret

parser_err_attempted_cell_access_in_layers:
    leaq .err_msg_attempted_cell_access_in_layers(%rip), %rdi
    movq $ERR_MSG_ATTEMPTED_CELL_ACCESS_IN_LAYERS_LEN, %rsi
    popq %rax
    movq $-1, %rax
    ret

parser_err_chained_leach_expr_must_end_in_massacre:
    leaq .err_msg_chained_leach_expr_must_end_in_massacre(%rip), %rdi
    movq $ERR_MSG_CHAINED_LEACH_EXPR_MUST_END_IN_MASSACRE_LEN, %rsi
    popq %rax
    movq $-1, %rax
    ret

parser_err_attempt_to_leach_expr_onto_itself:
    leaq .err_msg_attempt_to_leach_expr_onto_itself(%rip), %rdi
    movq $ERR_MSG_ATTEMPT_TO_LEACH_EXPR_ONTO_ITSELF_LEN, %rsi
    popq %rax
    movq $-1, %rax
    ret

parser_err_expected_cell_expr:
    leaq .err_msg_expected_cell_expr(%rip), %rdi
    movq $ERR_MSG_EXPECTED_CELL_EXPR_LEN, %rsi
    popq %rax
    movq $-1, %rax
    ret

parser_err_leach_expr_must_start_with_primitive_or_cell:
    leaq .err_msg_leach_expr_must_start_with_primitive_or_cell(%rip), %rdi
    movq $ERR_MSG_LEACH_EXPR_MUST_START_WITH_PRIMITIVE_OR_CELL_LEN, %rsi
    popq %rax
    movq $-1, %rax
    ret

parser_err_attempted_primitive_access_in_cells:
    leaq .err_msg_attempted_primitive_access_in_cells(%rip), %rdi
    movq $ERR_MSG_ATTEMPTED_PRIMITIVE_ACCESS_IN_CELLS_LEN, %rsi
    popq %rax
    movq $-1, %rax
    ret

parser_err_only_org_expr:
    leaq .err_msg_only_org_expr(%rip), %rdi
    movq $ERR_MSG_ONLY_ORG_EXPR_LEN, %rsi
    popq %rax
    movq $-1, %rax
    ret

parser_err_end_of_chain_leach_expr_without_chain_leach_expr:
    leaq .err_msg_end_of_chain_leach_expr_without_chain_leach_expr(%rip), %rdi
    movq $ERR_MSG_END_OF_CHAIN_LEACH_EXPR_WITHOUT_CHAIN_LEACH_EXPR_LEN, %rsi
    popq %rax
    movq $-1, %rax
    ret

parser_err_triple_six_eq_not_expected:
    leaq .err_msg_triple_six_eq_not_expected(%rip), %rdi
    movq $ERR_MSG_TRIPLE_SIX_EQ_NOT_EXPECTED_LEN, %rsi
    popq %rax
    movq $-1, %rax
    ret

parser_err_triple_six_not_expected:
    leaq .err_msg_triple_six_not_expected(%rip), %rdi
    movq $ERR_MSG_TRIPLE_SIX_NOT_EXPECTED_LEN, %rsi
    popq %rax
    movq $-1, %rax
    ret

parser_err_jumps_to_non_existent_labels:
    leaq .err_msg_jumps_to_non_existent_labels(%rip), %rdi
    movq $ERR_MSG_JUMPS_TO_NON_EXISTENT_LABELS_LEN, %rsi
    popq %rax
    movq $-1, %rax
    ret

# Role
# ----
# Print parsed Expressions for debugging
parser_print_org_expr:
    pushq %rax
    call parser_print_org_expr_rec
    popq %rax
    leaq .newline(%rip), %rdi
    movq $1, %rsi
    call utils_print
    ret

parser_print_org_expr_rec:
    cmp $NULL_EXPRESSION, (%rax)
    je parser_print_org_expr_null_and_end
    leaq .org_expr_repr_start, %rdi
    movq $ORG_EXPR_REPR_START_LEN, %rsi
    call utils_print
    movq ORG_EXPR_CHILD_OFFSET(%rax), %r8
    call parser_print_org_expr_child
    movq ORG_EXPR_NEXT_ORG_OFFSET(%rax), %rax
    call parser_print_org_expr_rec
    leaq .org_expr_repr_end, %rdi
    movq $ORG_EXPR_REPR_END_LEN, %rsi
    call utils_print
    ret

parser_print_org_expr_null_and_end:
    leaq .org_expr_repr_null, %rdi
    movq $ORG_EXPR_REPR_NULL_LEN, %rsi
    call utils_print
    ret

parser_print_org_expr_rec_end:
    leaq .org_expr_repr_end, %rdi
    movq $ORG_EXPR_REPR_END_LEN, %rsi
    call utils_print
    ret

parser_print_org_expr_child:
    leaq .org_expr_child_repr_start, %rdi
    movq $ORG_EXPR_CHILD_REPR_START_LEN, %rsi
    call utils_print
    cmpb $REGION_EXPRESSION, (%r8)
    je parser_print_region_expr
    cmpb $DRILL_EXPRESSION, (%r8)
    je parser_print_drill_expr
    cmpb $LABEL_EXPRESSION, (%r8)
    je parser_print_label_expr
    cmpb $JUMP_EXPRESSION, (%r8)
    je parser_print_jump_expr
    cmpb $CELL_EXPRESSION, (%r8)
    je parser_print_cell_expr
    cmpb $LEACH_EXPRESSION, (%r8)
    je parser_print_leach_expr
    cmpb $PRIMITIVE_EXPRESSION, (%r8)
    je parser_print_primitive_expr
    movq $6666666666666, %rdi           # Just to show that something is wrong
    call utils_printint

parser_print_org_expr_child_end:
    leaq .org_expr_child_repr_end, %rdi
    movq $ORG_EXPR_CHILD_REPR_END_LEN, %rsi
    call utils_print
    ret

parser_print_region_expr:
    leaq .region_expr_repr_start, %rdi
    movq $REGION_EXPR_REPR_START_LEN, %rsi
    call utils_print
    cmp $CELLS_REGION, REGION_EXPR_IDENT_ADDR_OFFSET(%r8)
    je parser_print_region_expr_cells
    jmp parser_print_region_expr_layers

parser_print_region_expr_cells:
    leaq .region_repr_cells, %rdi
    movq $REGION_REPR_CELLS_LEN, %rsi
    call utils_print
    jmp parser_print_region_expr_end

parser_print_region_expr_layers:
    leaq .region_repr_layers, %rdi
    movq $REGION_REPR_LAYERS_LEN, %rsi
    call utils_print
    jmp parser_print_region_expr_end

parser_print_region_expr_end:
    leaq .region_expr_repr_end, %rdi
    movq $REGION_EXPR_REPR_END_LEN, %rsi
    call utils_print
    jmp parser_print_org_expr_child_end

parser_print_drill_expr:
    leaq .drill_expr_repr, %rdi
    movq $DRILL_EXPR_REPR_LEN, %rsi
    call utils_print
    jmp parser_print_org_expr_child_end

parser_print_label_expr:
    leaq .label_expr_repr_start, %rdi
    movq $LABEL_EXPR_REPR_START_LEN, %rsi
    call utils_print
    movq LABEL_EXPR_NAME_ADDR_OFFSET(%r8), %rdi
    pushq %rax
    call utils_strlen
    movq %rax, %rsi
    call utils_print
    leaq .label_expr_repr_end, %rdi
    movq $LABEL_EXPR_REPR_END_LEN, %rsi
    call utils_print
    popq %rax
    jmp parser_print_org_expr_child_end

parser_print_jump_expr:
    leaq .jump_expr_repr_start, %rdi
    movq $JUMP_EXPR_REPR_START_LEN, %rsi
    call utils_print
    movq JUMP_EXPR_NAME_ADDR_OFFSET(%r8), %rdi
    pushq %rax
    call utils_strlen
    movq %rax, %rsi
    call utils_print
    movq JUMP_EXPR_IS_COND_OFFSET(%r8), %r9
    cmp $CONDITIONAL_JUMP, %r9
    je parser_print_jmp_expr_cond
    jmp parser_print_jmp_expr_uncond

parser_print_jmp_expr_cond:
    leaq .jump_expr_cond_field_repr(%rip), %rdi
    movq $JUMP_EXPR_COND_FIELD_REPR, %rsi
    call utils_print
    jmp parser_print_jmp_expr_end

parser_print_jmp_expr_uncond:
    leaq .jump_expr_uncond_field_repr(%rip), %rdi
    movq $JUMP_EXPR_UNCOND_FIELD_REPR, %rsi
    call utils_print
    jmp parser_print_jmp_expr_end

parser_print_jmp_expr_end:
    leaq .jump_expr_repr_end(%rip), %rdi
    movq $JUMP_EXPR_REPR_END_LEN, %rsi
    call utils_print
    popq %rax
    jmp parser_print_org_expr_child_end

parser_print_cell_expr:
    pushq %rax
    leaq .cell_expr_repr_start(%rip), %rdi
    movq $CELL_EXPR_REPR_START_LEN, %rsi
    call utils_print
    movq CELL_EXPR_IDENT_ADDR_OFFSET(%r8), %rdi
    call utils_strlen
    movq %rax, %rsi
    call utils_print
    leaq .cell_expr_repr_end(%rip), %rdi
    movq $CELL_EXPR_REPR_END_LEN, %rsi
    call utils_print
    popq %rax
    jmp parser_print_org_expr_child_end

parser_print_leach_expr:
    call parser_print_leach_expr_loop
    jmp parser_print_org_expr_child_end

parser_print_leach_expr_loop:
    leaq .leach_expr_repr_start(%rip), %rdi
    movq $LEACH_EXPR_REPR_START_LEN, %rsi
    call utils_print
    movb LEACH_EXPR_IS_CHAIN_OFFSET(%r8), %r15b
    andq $0xff, %r15
    cmp $0, %r15
    je parser_print_leach_expr_no_chain
    jmp parser_print_leach_expr_chain

parser_print_leach_expr_no_chain:
    leaq .leach_expr_is_not_chain_field_repr(%rip), %rdi
    movq $LEACH_EXPR_IS_NOT_CHAIN_FIELD_REPR_LEN, %rsi
    call utils_print
    jmp parser_print_leach_expr_print_regions

parser_print_leach_expr_chain:
    leaq .leach_expr_is_chain_field_repr(%rip), %rdi
    movq $LEACH_EXPR_IS_CHAIN_FIELD_REPR_LEN, %rsi
    call utils_print
    jmp parser_print_leach_expr_print_regions

parser_print_leach_expr_print_regions:
    leaq .leach_expr_regions_field_repr_start(%rip), %rdi
    movq $LEACH_EXPR_REGIONS_FIELD_REPR_START_LEN, %rsi
    call utils_print
    
    movq LEACH_EXPR_REGION_CHANGES_OFFSET(%r8), %r13
    call parser_print_leach_expr_print_region_exprs

    leaq .leach_expr_regions_field_repr_end(%rip), %rdi
    movq $LEACH_EXPR_REGIONS_FIELD_REPR_END_LEN, %rsi
    call utils_print
    jmp parser_print_leach_expr_print_left_expr

parser_print_leach_expr_print_region_exprs:
    cmp $0, %r13
    je parser_return
    call parser_print_leach_expr_print_region_exprs_loop
    ret

parser_print_leach_expr_print_region_exprs_loop:
    call parser_print_leach_expr_print_region_expr_loop_go_deeper
    leaq .region_expr_repr_start(%rip), %rdi
    movq $REGION_EXPR_REPR_START_LEN, %rsi
    call utils_print
    movq (%r13), %rdi
    movq REGION_EXPR_IDENT_ADDR_OFFSET(%rdi), %rdi
    movq $1, %rsi
    call utils_print
    leaq .region_expr_repr_end(%rip), %rdi
    movq $REGION_EXPR_REPR_END_LEN, %rsi
    call utils_print
    ret

parser_print_leach_expr_print_region_expr_loop_go_deeper:
    cmp $0, LIST_NEXT(%r13)
    je parser_return
    pushq %r13
    movq LIST_NEXT(%r13), %r13
    call parser_print_leach_expr_print_region_exprs_loop
    popq %r13
    leaq .comma_space(%rip), %rdi
    movq $COMMA_SPACE_LEN, %rsi
    call utils_print
    ret

parser_print_leach_expr_print_left_expr:
    leaq .leach_expr_left_field_repr_start(%rip), %rdi
    movq $LEACH_EXPR_LEFT_FIELD_REPR_START_LEN, %rsi
    call utils_print
    movq LEACH_EXPR_LEFT_EXPR_OFFSET(%r8), %r13
    cmpb $CELL_EXPRESSION, (%r13)
    je parser_print_leach_expr_print_left_cell_expr
    jmp parser_print_leach_expr_print_left_primitive_expr

parser_print_leach_expr_print_left_cell_expr:
    leaq .cell_expr_repr_start(%rip), %rdi
    movq $CELL_EXPR_REPR_START_LEN, %rsi
    call utils_print
    movq LEACH_EXPR_LEFT_EXPR_OFFSET(%r8), %rdi
    movq CELL_EXPR_IDENT_ADDR_OFFSET(%r13), %rdi
    pushq %rax
    call utils_strlen
    movq %rax, %rsi
    popq %rax
    call utils_print
    leaq .cell_expr_repr_end(%rip), %rdi
    movq $CELL_EXPR_REPR_END_LEN, %rsi
    call utils_print
    jmp parser_print_leach_expr_print_right_expr

parser_print_leach_expr_print_left_primitive_expr:
    leaq .primitive_expr_repr_start(%rip), %rdi
    movq $PRIMITIVE_EXPR_REPR_START_LEN, %rsi
    call utils_print
    movq LEACH_EXPR_LEFT_EXPR_OFFSET(%r8), %rdi
    movq PRIMITIVE_EXPR_IDENT_ADDR_OFFSET(%r13), %rdi
    pushq %rax
    call utils_strlen
    movq %rax, %rsi
    popq %rax
    call utils_print
    leaq .primitive_expr_repr_end(%rip), %rdi
    movq $PRIMITIVE_EXPR_REPR_END_LEN, %rsi
    call utils_print
    jmp parser_print_leach_expr_print_right_expr

parser_print_leach_expr_print_right_expr:
    leaq .leach_expr_right_field_repr_start(%rip), %rdi
    movq $LEACH_EXPR_RIGHT_FIELD_REPR_START_LEN, %rsi
    call utils_print
    movq LEACH_EXPR_RIGHT_EXPR_OFFSET(%r8), %r13
    cmp $0, %r13
    je parser_print_leach_expr_last_leach_end
    movq %r13, %r8
    call parser_print_leach_expr_loop
    jmp parser_print_leach_expr_end

parser_print_leach_expr_last_leach_end:
    leaq .org_expr_repr_null(%rip), %rdi
    movq $ORG_EXPR_REPR_NULL_LEN, %rsi
    call utils_print
    jmp parser_print_leach_expr_end

parser_print_leach_expr_end:
    leaq .leach_expr_repr_end(%rip), %rdi
    movq $LEACH_EXPR_REPR_END_LEN, %rsi
    call utils_print
    ret

parser_print_primitive_expr:
    pushq %rax
    leaq .primitive_expr_repr_start(%rip), %rdi
    movq $PRIMITIVE_EXPR_REPR_START_LEN, %rsi
    call utils_print
    movq PRIMITIVE_EXPR_IDENT_ADDR_OFFSET(%r8), %rdi
    call utils_strlen
    movq %rax, %rsi
    call utils_print
    leaq .primitive_expr_repr_end(%rip), %rdi
    movq $PRIMITIVE_EXPR_REPR_END_LEN, %rsi
    call utils_print
    popq %rax
    jmp parser_print_org_expr_child_end

# Role
# ----
# Print the encountered labels, for debugging
parser_print_encountered_labels:
    movq %rdx, %r15                             # Address of encountered labels array
    movq %r14, %r14                             # Number of labels in encountered labels array
    leaq .print_encountered_labels_header(%rip), %rdi
    movq $PRINT_ENCOUNTERED_LABELS_HEADER_LEN, %rsi
    call utils_print
    jmp parser_print_string_array

parser_print_encountered_jumps:
    movq %r10, %r15
    movq %rbp, %r14
    leaq .print_encountered_jumps_header(%rip), %rdi
    movq $PRINT_ENCOUNTERED_JUMPS_HEADER_LEN, %rsi
    call utils_print
    jmp parser_print_string_array

parser_print_string_array:
    pushq %rdi
    pushq %rsi
    movq $0, %r8                # Index of string array
    jmp parser_print_string_array_loop

parser_print_string_array_loop:
    cmp %r8, %r14               # Is the index == the length
    je parser_print_string_array_loop_end
    movq %r15, %r13
    movq %r8, %r9
    imul $8, %r9
    addq %r9, %r13              # Calculate address of string address at %r8th index in array
    movq (%r13), %rdi           # String address
    call utils_strlen
    movq %rax, %rsi
    call utils_print
    call utils_print_newline
    incq %r8
    jmp parser_print_string_array_loop

parser_print_string_array_loop_end:
    popq %rsi
    popq %rdi
    call utils_print_newline
    ret