	// Authors: Luke Magdalin, Andrew Harnett
	// EECE.3170 Microprocessors I 
	// University of Massachusetts Lowell
   // March 19, 2026
   

	    .global picoword
        .type picoword, %function
picoword:
    // code here
setup:

loop:

convertToSegmentValues:

convertToDecimalArray:

readRegister:

writeRegister:


// initial variables
.data

PIN_DATA_IN .word #5 // gpio 5
PIN_LATCH_IN .word #3 // gpio 3
PIN_CLK_IN .word #4 // gpio 4

PIN_DATA_OUT_A .word #7 // gpio 7
PIN_DATA_OUT_B .word #8 // gpio 8
PIN_CLK_OUT .word #9 // gpio 9

NUM_DIGITS .word #10 // number of digits the display can show
