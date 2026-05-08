# Authors: Luke Magdalin, Andrew Harnett
# EECE.3170 Microprocessors I
# University of Massachusetts Lowell
# March 19, 2026

    .syntax unified
    .cpu cortex-m0plus

    .equ NUM_DIGITS,        10
    .equ PIN_DATA_IN,       5
    .equ PIN_LATCH_IN,      3
    .equ PIN_CLK_IN,        4
    .equ PIN_DATA_OUT_A,    7
    .equ PIN_DATA_OUT_B,    8
    .equ PIN_CLK_OUT,       9

    .equ SIO_BASE,          0xD0000000
    .equ SIO_GPIO_IN,       0x04
    .equ SIO_GPIO_OUT_SET,  0x14
    .equ SIO_GPIO_OUT_CLR,  0x18
    .equ DELAY_COUNT,       200
    .equ DELAY_3US,         252

    .global picoword
    .type picoword, %function
    .thumb_func
picoword:
    BL      setup
.main_loop:
    BL      loop
    B       .main_loop

    .thumb_func
setup:
    PUSH    {r4, lr}

    LDR     r4, =0x40014004
    MOVS    r1, #5

    MOVS    r2, #PIN_LATCH_IN
    LSLS    r2, r2, #3
    STR     r1, [r4, r2]

    MOVS    r2, #PIN_CLK_IN
    LSLS    r2, r2, #3
    STR     r1, [r4, r2]

    MOVS    r2, #PIN_DATA_IN
    LSLS    r2, r2, #3
    STR     r1, [r4, r2]

    MOVS    r2, #PIN_DATA_OUT_A
    LSLS    r2, r2, #3
    STR     r1, [r4, r2]

    MOVS    r2, #PIN_DATA_OUT_B
    LSLS    r2, r2, #3
    STR     r1, [r4, r2]

    MOVS    r2, #PIN_CLK_OUT
    LSLS    r2, r2, #3
    STR     r1, [r4, r2]

    LDR     r0, =0xD0000024
    LDR     r1, =0x398
    STR     r1, [r0]

    LDR     r0, =0xD0000028
    MOVS    r1, #(1 << PIN_DATA_IN)
    STR     r1, [r0]

    POP     {r4, pc}

    .thumb_func
loop:
    PUSH    {r4, lr}

    BL      read_register
    MOV     r4, r0

    SUB     sp, sp, #12
    MOVS    r1, #0
    STR     r1, [sp, #0]
    STR     r1, [sp, #4]
    STR     r1, [sp, #8]

    STR     r4, [sp, #0]

    MOV     r0, sp
    BL      write_register

    ADD     sp, sp, #12
    POP     {r4, pc}

    .thumb_func
    .global write_register
write_register:
    PUSH    {r4, r5, r6, r7, lr}
    SUB     sp, sp, #12
    MOV     r4, r0

    MOVS    r0, #0
.rev_loop:
    # MOVS    r1, #(NUM_DIGITS - 1)
    # SUBS    r1, r1, r0 
    # ADDS    r2, r4, r1
    LDRB    r2, [r2]
    MOV     r3, sp
    ADDS    r3, r3, r0
    STRB    r2, [r3]

    ADDS    r0, r0, #1
    CMP     r0, #NUM_DIGITS
    BLT     .rev_loop

    LDR     r4, =SIO_BASE
    MOVS    r5, #1
    LSLS    r5, r5, #PIN_CLK_OUT

    MOVS    r6, #0

.outer_loop:
    MOVS    r7, #0

.inner_loop:
    MOV     r0, sp
    ADDS    r0, r0, r6
    LDRB    r0, [r0]
    LSRS    r0, r0, r7
    MOVS    r1, #1
    ANDS    r0, r0, r1

    MOVS    r1, #1
    LSLS    r1, r1, #PIN_DATA_OUT_A
    CMP     r0, #1
    BEQ     .set_a_high
    STR     r1, [r4, #SIO_GPIO_OUT_CLR]
    B       .done_a
.set_a_high:
    STR     r1, [r4, #SIO_GPIO_OUT_SET]
.done_a:

    MOVS    r2, #(NUM_DIGITS/2)
    ADDS    r2, r2, r6
    MOV     r3, sp
    ADDS    r2, r3, r2
    LDRB    r2, [r2]
    LSRS    r2, r2, r7
    MOVS    r3, #1
    ANDS    r2, r2, r3

    MOVS    r3, #1
    LSLS    r3, r3, #PIN_DATA_OUT_B
    CMP     r2, #1
    BEQ     .set_b_high
    STR     r3, [r4, #SIO_GPIO_OUT_CLR]
    B       .done_b
.set_b_high:
    STR     r3, [r4, #SIO_GPIO_OUT_SET]
.done_b:

    LDR     r0, =DELAY_3US
.wr_delay_a:
    SUBS    r0, r0, #1
    BNE     .wr_delay_a

    STR     r5, [r4, #SIO_GPIO_OUT_SET]

    LDR     r0, =DELAY_3US
.wr_delay_b:
    SUBS    r0, r0, #1
    BNE     .wr_delay_b

    STR     r5, [r4, #SIO_GPIO_OUT_CLR]

    ADDS    r7, r7, #1
    CMP     r7, #8
    BLT     .inner_loop

    ADDS    r6, r6, #1
    CMP     r6, #(NUM_DIGITS/2)
    BLT     .outer_loop

    ADD     sp, sp, #12
    POP     {r4, r5, r6, r7, pc}

    .thumb_func
read_register:
    PUSH    {r4, r5, r6, r7, lr}

    LDR     r4, =SIO_BASE
    MOVS    r5, #(1 << PIN_LATCH_IN)
    MOVS    r6, #(1 << PIN_CLK_IN)
    MOVS    r7, #0

    STR     r5, [r4, #SIO_GPIO_OUT_CLR] 
    STR     r6, [r4, #SIO_GPIO_OUT_SET] 

    LDR     r0, =DELAY_3US
.delay_a:
    SUBS    r0, r0, #1
    BNE     .delay_a

    STR     r6, [r4, #SIO_GPIO_OUT_CLR]

    LDR     r0, =DELAY_3US
.delay_b:
    SUBS    r0, r0, #1
    BNE     .delay_b

    STR     r5, [r4, #SIO_GPIO_OUT_SET] 

    MOVS    r1, #31

.read_loop:
    LDR     r0, [r4, #SIO_GPIO_IN]
    MOVS    r2, #(1 << PIN_DATA_IN)
    ANDS    r0, r0, r2
    LSRS    r0, r0, #PIN_DATA_IN
    LSLS    r0, r0, r1
    ORRS    r7, r7, r0

    STR     r6, [r4, #SIO_GPIO_OUT_SET] 

    LDR     r0, =DELAY_3US
.delay_c:
    SUBS    r0, r0, #1
    BNE     .delay_c

    STR     r6, [r4, #SIO_GPIO_OUT_CLR]

    LDR     r0, =DELAY_3US
.delay_d:
    SUBS    r0, r0, #1
    BNE     .delay_d

    SUBS    r1, r1, #1
    BPL     .read_loop

    MOVS    r0, r7
    POP     {r4, r5, r6, r7, pc}


convertToSegmentValues:


convertToDecimalArray:


    .section .data
segmentCodes:
    .byte 0b11111100    # 0
    .byte 0b01100000    # 1
    .byte 0b11011010    # 2
    .byte 0b11110010    # 3
    .byte 0b01100110    # 4
    .byte 0b10110110    # 5
    .byte 0b10111110    # 6
    .byte 0b11100000    # 7
    .byte 0b11111110    # 8
    .byte 0b11100110    # 9

decimalDigitArray:
    .space 10

segmentValues:
    .space 10