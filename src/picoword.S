	// Authors: Luke Magdalin, Andrew Harnett
	// EECE.3170 Microprocessors I 
	// University of Massachusetts Lowell
    // March 19, 2026
    
    .equ NUM_DIGITS, 10
    .equ PIN_DATA_IN, 5
    .equ PIN_LATCH_IN, 3
    .equ PIN_CLK_IN, 4
    .equ PIN_DATA_OUT_A, 7
    .equ PIN_DATA_OUT_B, 8
    .equ PIN_CLK_OUT, 9
    
	    .global picoword
         .type picoword, %function

picoword:
    bl setup            // Init the pins
    b loop              // Start the main loop

setup:
    ldr r0, =0xd0000020   // Address for output enable
    ldr r1, =0x398        // 3,4,7,8,9 as outputs, 5 as input
    str r1, [r0]          // Apply the config
    bx lr

loop:
    bl readRegister       // Get the 32-bit value from the switches
    mov r0, r0            // Value is already in r0
    ldr r1, =decimalDigitArray
    bl convertToDecimalArray // Turn binary into digits
    ldr r0, =decimalDigitArray
    ldr r1, =segmentValues
    bl convertToSegmentValues // Turn digits into 7-seg codes
    ldr r0, =segmentValues
    bl writeRegister      // Send codes to the displays
    b loop                // Do it all over again

readRegister:
    push {r4, r5, lr}
    ldr r4, =0xd0000000   // GPIO base address
    
    // Pull latch low to let registers get values from switches
    mov r1, # (1 << PIN_LATCH_IN)
    str r1, [r4, #0x18]   // Clear pin
    
    // Quick clock pulse to trigger the read
    mov r1, # (1 << PIN_CLK_IN)
    str r1, [r4, #0x14]   // Set pin
    bl delay_1us
    str r1, [r4, #0x18]   // Clear pin
    bl delay_1us
    
    // Pull latch high to lock the values in
    mov r1, # (1 << PIN_LATCH_IN)
    str r1, [r4, #0x14]   // Set pin
    
    mov r0, #0            // Clear our result register
    mov r5, #32           // We need to read 32 bits total
read_loop:
    // Check if the data pin is high or low
    ldr r2, [r4, #0x24]   // Read all input pins
    mov r1, # (1 << PIN_DATA_IN)
    tst r2, r1
    mov r3, #0
    beq read_bit_zero
    mov r3, #1
read_bit_zero:
    // Shift the bit we just read into the result
    lsl r0, r0, #1
    orr r0, r0, r3
    
    // Clock pulse to move to the next bit in the register
    mov r1, # (1 << PIN_CLK_IN)
    str r1, [r4, #0x14]   // Set
    bl delay_1us
    str r1, [r4, #0x18]   // Clear
    bl delay_1us
    
    sub r5, r5, #1       // One less bit to go
    cmp r5, #0
    bne read_loop         // Repeat until all 32 are read
    
    pop {r4, r5, pc}

writeRegister:
    push {r4, r5, r6, r7, lr}
    ldr r4, =0xd0000000   // GPIO base address
    mov r5, #0            // i = 0 (digit counter)
    mov r1, #1            // Constant 1 for testing bits
write_outer:
    // Grab the segment codes for both channels (going backwards)
    // R0 is the pointer to our segment values array
    mov r2, #9
    sub r2, r2, r5
    ldrb r2, [r0, r2]     // Byte for channel A
    
    mov r3, #4
    sub r3, r3, r5
    ldrb r3, [r0, r3]     // Byte for channel B
    
    mov r6, #0            // j = 0 (bit counter)
write_inner:
    // Handle channel A bit
    mov r7, r2
    lsr r7, r6            // Shift current bit to the end
    tst r7, r1            // Use r1 for the constant 1
    beq set_a_low
    
    ldr r2, =PIN_DATA_OUT_A_MASK
    ldr r2, [r2]
    str r2, [r4, #0x14]   // Set pin high
    b clock_pulse
set_a_low:
    ldr r2, =PIN_DATA_OUT_A_MASK
    ldr r2, [r2]
    str r2, [r4, #0x18]   // Set pin low

clock_pulse:
    // Handle channel B bit
    mov r7, r3
    lsr r7, r6            // Shift current bit to the end
    tst r7, r1            // Use r1 for the constant 1
    beq set_b_low
    
    ldr r2, =PIN_DATA_OUT_B_MASK
    ldr r2, [r2]
    str r2, [r4, #0x14]   // Set pin high
    b pulse_clock
set_b_low:
    ldr r2, =PIN_DATA_OUT_B_MASK
    ldr r2, [r2]
    str r2, [r4, #0x18]   // Set pin low

pulse_clock:
    // Send a clock pulse to push the bits into the shift register
    ldr r2, =PIN_CLK_OUT_MASK
    ldr r2, [r2]
    str r2, [r4, #0x14]   // High
    bl delay_1us
    str r2, [r4, #0x18]   // Low
    bl delay_1us
    
    add r6, r6, #1        // Move to next bit
    cmp r6, #8
    bne write_inner       // Do 8 bits per byte
    
    add r5, r5, #1        // Move to next digit
    cmp r5, #5
    bne write_outer       // Do 5 digits per channel
    
    pop {r4, r5, r6, r7, pc}

delay_1us:
    push {r4}
    mov r4, #30          // Just a small loop to waste some time
delay_loop:
    sub r4, r4, #1
    cmp r4, #0
    bne delay_loop
    pop {r4}
    bx lr



convertToSegmentValues:
    push {r4, r5, lr}
    mov r4, #0            // i = 0
conv_seg_loop:
    ldrb r2, [r0, r4]     // Get digit from decimalDigitArray
    ldr r3, =segmentCodes // Get table address
    ldrb r3, [r3, r2]     // Get code for that digit
    strb r3, [r1, r4]     // Store it in segmentValues
    add r4, r4, #1
    cmp r4, #10
    bne conv_seg_loop
    pop {r4, r5, pc}

convertToDecimalArray:
    push {r4, r5, r6, lr}
    mov r4, #0            // Digit counter i = 0
decimal_loop:
    // Division by 10: r0 is the number to divide
    mov r2, #0            // Quotient = 0
    mov r3, #0            // Remainder = 0
    mov r5, #31           // Start from MSB
    mov r6, #1            // Constant 1
div_bit_loop:
    lsl r3, r3, #1        // Remainder = Remainder * 2
    // Extract bit from r0 at position r5
    mov r7, #1
    lsl r7, r5
    tst r0, r7
    beq skip_bit
    orr r3, r3, r6        // Use r6 for the constant 1
skip_bit:
    cmp r3, #10
    blt skip_sub
    sub r3, r3, #10       // Subtract 10 from remainder
    add r2, r2, #1        // Increment quotient
skip_sub:
    sub r5, r5, #1        // Move to next bit
    cmp r5, #0            // Check if we've finished bit 0
    bge div_bit_loop
    
    // Now r3 is the remainder (r0 % 10)
    // Store the remainder in decimalDigitArray
    ldr r1, =decimalDigitArray
    strb r3, [r1, r4]
    
    // Set r0 to the quotient for the next digit
    mov r0, r2
    
    add r4, r4, #1        // Next digit
    cmp r4, #10
    bne decimal_loop
    
    pop {r4, r5, r6, pc}




// Lookup table for reversed segment codes
.section .data
segmentCodes:
    .byte 0b11111100 // 0
    .byte 0b01100000 // 1
    .byte 0b11011010 // 2
    .byte 0b11110010 // 3
    .byte 0b01100110 // 4
    .byte 0b10110110 // 5
    .byte 0b10111110 // 6
    .byte 0b11100000 // 7
    .byte 0b11111110 // 8
    .byte 0b11100110 // 9

decimalDigitArray:
    .space 10

segmentValues:
    .space 10

PIN_DATA_OUT_A_MASK: .word (1 << PIN_DATA_OUT_A)
PIN_DATA_OUT_B_MASK: .word (1 << PIN_DATA_OUT_B)
PIN_CLK_OUT_MASK:    .word (1 << PIN_CLK_OUT)

