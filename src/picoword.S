# Authors: Luke Magdalin, Andrew Harnett
# EECE.3170 Microprocessors I
# University of Massachusetts Lowell
# March 19, 2026
.syntax unified             # Standard ARM syntax boilerplate
    .cpu cortex-m0plus          # Compiling for the Pico's brain

    .equ NUM_DIGITS,        10  # Total segments we are driving
    .equ PIN_DATA_IN,       5   # Where the data comes IN from the external register
    .equ PIN_LATCH_IN,      3   # Latch pin to grab the inputs
    .equ PIN_CLK_IN,        4   # Clock pin for reading
    .equ PIN_DATA_OUT_A,    7   # Output pin for Bank A
    .equ PIN_DATA_OUT_B,    8   # Output pin for Bank B
    .equ PIN_CLK_OUT,       9   # Clock pin for writing out

    .equ SIO_BASE,          0xD0000000 # Base address for fast single-cycle GPIO
    .equ SIO_GPIO_IN,       0x04       # Offset to read pins
    .equ SIO_GPIO_OUT_SET,  0x14       # Offset to turn pins HIGH
    .equ SIO_GPIO_OUT_CLR,  0x18       # Offset to turn pins LOW
    .equ DELAY_COUNT,       200        # Not used rn but keeping it just in case
    .equ DELAY_3US,         252        # Magic number loop counter for ~3 microsecond delay

    .global picoword
    .type picoword, %function
    .thumb_func
picoword:
    BL      setup               # Jump to setup first
.main_loop:
    BL      loop                # Run the main loop
    B       .main_loop          # Do it again forever

    .thumb_func
setup:
    PUSH    {r4, lr}            # Save r4 and link register so we can return later

    LDR     r4, =0x40014004     # Pointer to IO_BANK0 base (hardware stuff)
    MOVS    r1, #5              # 5 = "SIO" function for Pico pins

    MOVS    r2, #PIN_LATCH_IN   # Get latch pin number
    LSLS    r2, r2, #3          # Multiply by 8 to get the memory offset
    STR     r1, [r4, r2]        # Tell the hardware this pin is controlled by SIO

    MOVS    r2, #PIN_CLK_IN     # Same thing for clock in pin
    LSLS    r2, r2, #3
    STR     r1, [r4, r2]

    MOVS    r2, #PIN_DATA_IN    # Same thing for data in pin
    LSLS    r2, r2, #3
    STR     r1, [r4, r2]

    MOVS    r2, #PIN_DATA_OUT_A # Same thing for out A
    LSLS    r2, r2, #3
    STR     r1, [r4, r2]

    MOVS    r2, #PIN_DATA_OUT_B # Same thing for out B
    LSLS    r2, r2, #3
    STR     r1, [r4, r2]

    MOVS    r2, #PIN_CLK_OUT    # Same thing for out clock
    LSLS    r2, r2, #3
    STR     r1, [r4, r2]

    LDR     r0, =0xD0000024     # SIO_GPIO_OE (Output Enable) register
    LDR     r1, =0x398          # Bitmask for pins 7, 8, 9 (and maybe 3, 4?)
    STR     r1, [r0]            # Turn on the output pads for our write pins

    LDR     r0, =0xD0000028     # SIO_GPIO_OE_CLR (Output Disable) register
    MOVS    r1, #(1 << PIN_DATA_IN) # We want the input pin to be an actual input
    STR     r1, [r0]            # Disable output on data in pin

    POP     {r4, pc}            # Restore registers and return

    .thumb_func
loop:
    PUSH    {r4, lr}            # Save state

    BL      read_register       # Call read (returns 32-bit value in r0)
    MOV     r4, r0              # Stash it in r4 so it doesn't get overwritten

    SUB     sp, sp, #12         # Grab 12 bytes of stack space (must be word-aligned!)
    MOVS    r1, #0              # Get a zero ready
    STR     r1, [sp, #0]        # Zero out first 4 bytes
    STR     r1, [sp, #4]        # Zero out next 4 bytes
    STR     r1, [sp, #8]        # Zero out last 4 bytes (12 total)

    STR     r4, [sp, #0]        # Dump our 32-bit read value into the start of the array

    MOV     r0, sp              # Pass the stack pointer (our array address) to write_register
    BL      write_register      # Send it!

    ADD     sp, sp, #12         # Give the memory back to the stack
    POP     {r4, pc}            # Return

    .thumb_func
    .global write_register
write_register:
    PUSH    {r4, r5, r6, r7, lr} # Save all these registers, we need a lot of them
    SUB     sp, sp, #12         # Allocate another 12 bytes on stack for the copy
    MOV     r4, r0              # r4 now holds the address of our input array

    MOVS    r0, #0              # r0 = index i = 0
.rev_loop:
    # MOVS    r1, #(NUM_DIGITS - 1) # (Commented out the reverse math for testing!)
    # SUBS    r1, r1, r0        # (Commented out)
    # ADDS    r2, r4, r1        # (Commented out)
    ADDS    r2, r4, r0          # Instead, just copy straight across: r2 = array[i]
    LDRB    r2, [r2]            # Load the byte at that address
    MOV     r3, sp              # Get stack pointer
    ADDS    r3, r3, r0          # r3 = stack pointer + i
    STRB    r2, [r3]            # Store the byte there

    ADDS    r0, r0, #1          # i++
    CMP     r0, #NUM_DIGITS     # Have we hit 10 elements yet?
    BLT     .rev_loop           # If not, keep looping

    LDR     r4, =SIO_BASE       # Load the SIO base address for fast toggling
    MOVS    r5, #1              # Prepare a 1
    LSLS    r5, r5, #PIN_CLK_OUT # Shift it to make a clock pin mask (1 << 9)

    MOVS    r6, #0              # Outer loop counter (i = 0)

.outer_loop:
    MOVS    r7, #0              # Inner loop counter (j = 0, bit index)

.inner_loop:
    MOV     r0, sp              # Get array base
    ADDS    r0, r0, r6          # Add outer loop index (i)
    LDRB    r0, [r0]            # Grab the byte from the array
    LSRS    r0, r0, r7          # Shift right by j to get the current bit into position 0
    MOVS    r1, #1              # Masking value
    ANDS    r0, r0, r1          # AND it with 1 so r0 is exactly 0 or 1

    MOVS    r1, #1              # Prepare to toggle Bank A
    LSLS    r1, r1, #PIN_DATA_OUT_A # r1 = Bank A pin mask
    CMP     r0, #1              # Is our data bit a 1?
    BEQ     .set_a_high         # If yes, branch to set it high
    STR     r1, [r4, #SIO_GPIO_OUT_CLR] # Else, pull Bank A pin LOW
    B       .done_a             # Skip the high setting
.set_a_high:
    STR     r1, [r4, #SIO_GPIO_OUT_SET] # Pull Bank A pin HIGH
.done_a:

    MOVS    r2, #(NUM_DIGITS/2) # Now for Bank B... offset by 5 (NUM_DIGITS/2)
    ADDS    r2, r2, r6          # r2 = i + 5
    MOV     r3, sp              # Base array address
    ADDS    r2, r3, r2          # Add offset to base address
    LDRB    r2, [r2]            # Grab the byte for Bank B
    LSRS    r2, r2, r7          # Shift right by j to isolate bit
    MOVS    r3, #1              # Masking value
    ANDS    r2, r2, r3          # Isolate that LSB

    MOVS    r3, #1              # Prepare to toggle Bank B
    LSLS    r3, r3, #PIN_DATA_OUT_B # r3 = Bank B pin mask
    CMP     r2, #1              # Is Bank B's data bit a 1?
    BEQ     .set_b_high         # If yes, branch to high
    STR     r3, [r4, #SIO_GPIO_OUT_CLR] # Else, pull Bank B pin LOW
    B       .done_b             # Skip the high setting
.set_b_high:
    STR     r3, [r4, #SIO_GPIO_OUT_SET] # Pull Bank B pin HIGH
.done_b:

    LDR     r0, =DELAY_3US      # Load delay counter
.wr_delay_a:
    SUBS    r0, r0, #1          # Count down
    BNE     .wr_delay_a         # Loop until zero (creates a tiny pause)

    STR     r5, [r4, #SIO_GPIO_OUT_SET] # Pulse clock pin HIGH

    LDR     r0, =DELAY_3US      # Load delay again
.wr_delay_b:
    SUBS    r0, r0, #1          # Count down
    BNE     .wr_delay_b         # Loop until zero

    STR     r5, [r4, #SIO_GPIO_OUT_CLR] # Pulse clock pin LOW (finishing the pulse)

    ADDS    r7, r7, #1          # j++ (move to next bit)
    CMP     r7, #8              # Have we done all 8 bits in the byte?
    BLT     .inner_loop         # If not, do next bit

    ADDS    r6, r6, #1          # i++ (move to next byte)
    CMP     r6, #(NUM_DIGITS/2) # Have we done 5 bytes?
    BLT     .outer_loop         # If not, do next byte

    ADD     sp, sp, #12         # Clean up our stack array
    POP     {r4, r5, r6, r7, pc} # Restore registers and return

    .thumb_func
read_register:
    PUSH    {r4, r5, r6, r7, lr} # Save state

    LDR     r4, =SIO_BASE       # Load fast GPIO base address
    MOVS    r5, #(1 << PIN_LATCH_IN) # Mask for Latch pin
    MOVS    r6, #(1 << PIN_CLK_IN)   # Mask for Clock pin
    MOVS    r7, #0              # r7 will accumulate our 32 bits, start at 0

    STR     r5, [r4, #SIO_GPIO_OUT_CLR] # Pull LATCH LOW (loads data into shift reg)
    STR     r6, [r4, #SIO_GPIO_OUT_SET] # Pull CLK HIGH (prep for toggle)

    LDR     r0, =DELAY_3US      # Tiny delay
.delay_a:
    SUBS    r0, r0, #1
    BNE     .delay_a

    STR     r6, [r4, #SIO_GPIO_OUT_CLR] # Pull CLK LOW

    LDR     r0, =DELAY_3US      # Another tiny delay
.delay_b:
    SUBS    r0, r0, #1
    BNE     .delay_b

    STR     r5, [r4, #SIO_GPIO_OUT_SET] # Pull LATCH HIGH (lock the data in)

    MOVS    r1, #31             # Start index at 31 (reading MSB first)

.read_loop:
    LDR     r0, [r4, #SIO_GPIO_IN] # Read the state of ALL pins right now
    MOVS    r2, #(1 << PIN_DATA_IN) # Mask for just our data pin
    ANDS    r0, r0, r2          # Zero out everything except our pin
    LSRS    r0, r0, #PIN_DATA_IN # Shift it down so r0 is exactly 0 or 1
    LSLS    r0, r0, r1          # (THE FIX) Shift the 0 or 1 back up into the i-th position
    ORRS    r7, r7, r0          # Slap it into our accumulator register using OR

    STR     r6, [r4, #SIO_GPIO_OUT_SET] # Pulse clock HIGH

    LDR     r0, =DELAY_3US      # Wait a sec
.delay_c:
    SUBS    r0, r0, #1
    BNE     .delay_c

    STR     r6, [r4, #SIO_GPIO_OUT_CLR] # Pulse clock LOW

    LDR     r0, =DELAY_3US      # Wait another sec
.delay_d:
    SUBS    r0, r0, #1
    BNE     .delay_d

    SUBS    r1, r1, #1          # Decrement our bit counter
    BPL     .read_loop          # If i is still >= 0, keep looping!

    MOVS    r0, r7              # Move our final 32-bit number into r0 to return it
    POP     {r4, r5, r6, r7, pc} # Pop everything and return


convertToSegmentValues:
    # (Empty for now, gonna do this later)

convertToDecimalArray:
    # (Also empty, future me problem)

    .section .data
segmentCodes:                   # Lookup table for 7-seg digits (assuming active-low)
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
    .space 10                   # Reserving 10 bytes of memory here

segmentValues:
    .space 10                   # Reserving another 10 bytes here