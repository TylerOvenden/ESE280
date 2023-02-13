;
; ADC_sgnl_conv.asm
;
; Created: 11/17/2020 5:37:02 PM
; Author : tyler
;


; Replace with your application code
.nolist
.include "m4809def.inc"
.list

.dseg
.equ PERIOD_EXAMPLE_VALUE = 80 ; 40.06 hz
digit_number: .byte 1     ;creates variable representing the place of the digits
bcd_entires: .byte 4      ;creates array representing bcd digits
led_display: .byte 4      ;creates array representing the led
hex_values: .byte 4       ;creates array of hex values 

.cseg				;start of code segment
reset:
 	jmp start			;reset vector executed a power on

.org TCA0_OVF_vect
	 jmp display_ISR


	 ;***************************************************************************
;*

;* Title: Analog voltage measurement 
;* Author:				Tyler Ovenden
;* Version:				1.0
;* Last updated:		11/18/20
;* Target:				ATmega4809 @3.3MHz
;*
;* DESCRIPTION
 ;*  measurings the voltage of the ADC using polling, turns on conversion & when conversion stops, read in the results
 ;* displays the resulting voltagee taken in
;* VERSION HISTORY
;* 1.0 Original version
;***************************************************************************


start:
    ; Configure I/O ports

	cbi VPORTE_DIR, 0	;PE0 input- gets output from PB1
	cbi VPORTE_DIR, 2	;PE2 input- gets output from PB2
		ldi r18, $00          ;0 in 7 segment display
	sts led_display, r18    ;resets all display digits to 0
	sts led_display+1, r18
	sts led_display+2, r18
	sts led_display+3, r18
	sts digit_number, r16   ;sets digital number to 0, to represent the first digit being set to display



	ldi r17, 0xFF          ;register to set outputs
	out VPORTC_DIR, r17     ;sets portc as output
	out VPORTD_DIR, r17     ;sets portd as output      





	ldi XH, HIGH(led_display)     ;creates pointer set to led_display array
	ldi XL, LOW(led_display)      ;
	



	


	ldi r16, TCA_SINGLE_WGMODE_NORMAL_gc  ;WGMODE normal 
	sts TCA0_SINGLE_CTRLB, r16 
	ldi r16, TCA_SINGLE_OVF_bm
	sts TCA0_SINGLE_INTCTRL, r16 

	;load period low byte then high byte
	ldi r16, LOW(PERIOD_EXAMPLE_VALUE)
	sts TCA0_SINGLE_PER, r16
	ldi r16, HIGH(PERIOD_EXAMPLE_VALUE)
	sts TCA0_SINGLE_PER+1, r16
	ldi r16, TCA_SINGLE_CLKSEL_DIV256_gc | TCA_SINGLE_ENABLE_bm
	sts TCA0_SINGLE_CTRLA, r16
	sei			;enable global interrupts
	

		ldi r16, 0x00     ;
	out VPORTA_DIR, r16    ;loads porta as an input
	ldi r17, 0xFF          ;register to set outputs
	out VPORTC_DIR, r17     ;sets portc as output
	out VPORTD_DIR, r17     ;sets portd as output      
	rcall delay
	ldi r16, 2              ;2 = configuring VREF to 2.5 v 
	sts VREF_CTRLA, r16     ;
	ldi r16, 4              ;4 = input disable, used to configure porte pin1 as analog
	sts PORTE_PIN1CTRL, r16
	ldi r16, 0              
	ori r16, 0x45        ;setting SAMPCAP to 1, setting ADC0 clock prescalar to divide by 64 (0100 0101) 
	sts ADC0_CTRLC, r16
	ldi r16, 9           ;configuring pin 9 as the mux input
	sts   ADC0_MUXPOS,r16
	ldi r16, 1           ;turn on ACD0
	sts ADC0_CTRLA, r16

main_loop:
rcall analogvolt
rjmp main_loop




;***************************************************************************
;* 
;* "analogvolt" - polling for voltage from ADC
;*
;* Description: starts a conversion for ADC, conversion ends when it finds adc0 flag set
;*  loads in the 2 byte result & places it in the display array
;* Author:                  Tyler Ovenden 
;* Version:                    1.0
;* Last updated:                    11/18/20
;* Target:						;ATmega4809 @ 3.3MHz
;* Number of words:            36
;* Number of cycles:           36
;* Low registers modified:	none
;* High registers modified:	r16, r17, r18, r19, r20
;*
;*
;* Returns: updated led_display with current values taken from the result
;* Notes: 
;*
;***************************************************************************

analogvolt:
	ldi r18, 1          ;enable polling	
	sts ADC0_COMMAND, r18  

	polling:
	lds r18, ADC0_INTFLAGS
	sbrs r18, 0
	rjmp polling
	lds r18, ADC0_RESL    ;low bit of result
	lds r19, ADC0_RESH    ;high bit of result
	mov r20, r18          ;make copies of result for isolating nibbles
	mov r21, r19 
	swap r20
	swap r21
	andi r18, 0x0F     ;isolating nibble for all of them 
	andi r19, 0x0F
	andi r20, 0x0F
	andi r21, 0x0F
	sts led_display, r18   ;
	sts led_display+1, r20
	sts led_display+2, r19
	sts led_display+3, r21


ret 




	;***************************************************************************
;* 
;* "display_ISR" - interupt for timer counter
;*
;* Description: when timer counter overflows is called, calls subroutine for multiplex
;* clears flag for timer counter 
;* Author:                  Tyler Ovenden 
;* Version:                    1.0
;* Last updated:                    11/18/20
;* Target:						;ATmega4809 @ 3.3MHz
;* Number of words:            3
;* Number of cycles:           108
;* Low registers modified:	none
;* High registers modified:	none
;*
;*
;*
;* Notes: 
;*
;***************************************************************************
	
    



	display_ISR: 
	push r16
	rcall multiplex
	ldi r16, TCA_SINGLE_OVF_bm ;clear OVF flag
	sts TCA0_SINGLE_INTFLAGS, r16
	pop r16
	reti			;return from PORTE pin change ISR



;***************************************************************************
;* 
;* "delay" - Multiplex the Four Digit LED Display
;*
;* Description: calls a delay for one second, then turns off all digits in array 
;*
;* Author:                  Tyler Ovenden 
;* Version:                    1.0
;* Last updated:                    10/29/20
;* Target:						;ATmega4809 @ 3.3MHz
;* Number of words:            31
;* Number of cycles:           98
;* Low registers modified:	none
;* High registers modified:	r16, r18
;*
;* Parameters:
;* led_display: a four byte array that holds the segment values
;*  for each digit of the display. led_display[0] holds the segment pattern
;*  for digit 0 (the rightmost digit) and so on.
;* digit_num: a byte variable, the least significant two bits provide the
;* index of the next digit to be displayed.
;*
;* Parameters: r17, bcd_entires
;* Returns: bcd_entires with added bcd value, updated led_display with current values from bcd_values converted to 7 segment
;* Notes: 
;*
;***************************************************************************

	delay: 

	ldi r16, 0xFA           ;load r16 with hex for 250, so there's a 250 ms delay
	rcall var_delay         ;calls var_delay once
	inc r19                 ;increase r19 which acts as a counter 
	cpi r19, 0x28           ;hex for 40, used to repeat loop 40 times because 250 ms * 40 = 1 second
	brne delay              ;branchs back to beginning if r19 is not 40
	ldi r19, 0x00           ;when it is 40, set r19 back to 0
	ldi r18, $01
	sts led_display, r18    ;resets all display digits to 0
	sts led_display+1, r18
	sts led_display+2, r18
	sts led_display+3, r18
	ret                     ;end subroutine


    var_delay: 
		outer_loop:
		ldi r17, 110              ;loads r17 with 110
		inner_loop: 
		dec r17                  ;decreases r17
		brne inner_loop         ;branchs to start of inner_loop if not equal
		dec r16                 ;decreases 16
		brne outer_loop          ;branchs to outer_loop if not equal

		ret            ;ends subroutine 
	








;***************************************************************************
;* 
;* "multiplex_display" - Multiplex the Four Digit LED Display
;*
;* Description: Updates a single digit of the display and increments the 
;*  digit_num to the value of the digit position to be displayed next.
;*
;* Author:                  Tyler Ovenden 
;* Version:                    1.0
;* Last updated:                    10/29/20
;* Target:						;ATmega4809 @ 3.3MHz
;* Number of words:             50
;* Number of cycles:           98
;* Low registers modified:	none
;* High registers modified:	none
;*
;* Parameters:
;* led_display: a four byte array that holds the segment values
;*  for each digit of the display. led_display[0] holds the segment pattern
;*  for digit 0 (the rightmost digit) and so on.
;* digit_num: a byte variable, the least significant two bits provide the
;* index of the next digit to be displayed.
;*
;* Parameters: r17, bcd_entires
;* Returns: bcd_entires with added bcd value, updated led_display with current values from bcd_values converted to 7 segment
;* Notes: 
;*
;***************************************************************************
	
	
	multiplex:
	push r16
	push r17
	push r18
	in r18, CPU_SREG
	push r18

	lds r16, digit_number            ;loads digit number into register
	ld r17, X+                       ;loads register with pointer's contents of array element, increases pointer
	cpi r16, 0                       ;checks if digit number is 0
	breq first
	cpi r16, 1                      ;checks if digit number is 1
	breq second
	cpi r16, 2                      ;checks if digit number is 2
	breq third
	cpi r16, 3                       ;checks if digit number is 3
	breq fourth
  first: 
  ldi r18, 0x7F 
            
	out VPORTC_OUT, r18             ;turns on first digit
	inc r16   
	rjmp end
 second: 

	ldi r18, 0xBF
	out VPORTC_OUT, r18            ;turns on second digit
	inc r16   
	rjmp end
 third: 
		ldi r18, 0xDF
	out VPORTC_OUT, r18           ;turns on 3rd digit
	inc r16   
	rjmp end
 fourth:   
	ldi r18, 0xEF   
	out VPORTC_OUT, r18            ;turns on 4th digit
	ldi XH, HIGH(led_display)     ;resets pointer 
	ldi XL, LOW(led_display)      ;
	ldi r16, 0                    ;resets registe for digit number
	rjmp end
 end:
	out VPORTD_OUT, r17            ;puts array contents into display                        
	sts digit_number, r16          ;increases digit number
	pop r18                        
	out CPU_SREG, r18
	pop r18                      
	pop r17
	pop r16
	ret

       

