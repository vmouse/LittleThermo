/*
 * LittleThermo.asm
 *
 *  Created: 16.10.2014 16:14:39
 *   Author: vlad
 */ 

 .include "avr.inc"

.EQU	led1 = PB0
.EQU	led2 = PB1
.EQU	led3 = PB2

//#define	F_CPU 8000000
#define	F_CPU 9600000

;----------------------------------------------------------;
; Data memory area

.dseg
.ORG	RAMTOP
.EQU	MaxInputSize	=	32 
LineBuf:.byte	MaxInputSize	;Command line characters buffer 
ByteBuf:.byte	MaxInputSize/2  ;Command line bytes buffer

;----------------------------------------------------------;
; Program code area

.CSEG
.ORG $0000

rjmp RESET ; Address 0x0000
/*
; Tiny 25/45/85 
RETI	;	rjmp INT0_ISR ; Address 0x0001
RETI	;	rjmp PCINT0_ISR ; Address 0x0002
RETI	;	rjmp TIM1_COMPA_ISR ; Address 0x0003
RETI	;	rjmp TIM1_OVF_ISR ; Address 0x0004
RETI	;	rjmp TIMER_ISR ;	rjmp TIM0_OVF_ISR ; Address 0x0005
RETI	;	rjmp EE_RDY_ISR ; Address 0x0006
RETI	;	rjmp ANA_COMP_ISR ; Address 0x0007
RETI	;	rjmp ADC_ISR ; Address 0x0008
RETI	;	rjmp TIM1_COMPB_ISR ; Address 0x0009
RETI	;	rjmp TIM0_COMPA_ISR ; Address 0x000A
RETI	;	rjmp TIM0_COMPB_ISR ; Address 0x000B
RETI	;	rjmp WDT_ISR ; Address 0x000C
RETI	;	rjmp USI_START_ISR ; Address 0x000D
RETI	;	rjmp USI_OVF_ISR ; Address 0x000E
*/
;Tiny13
RETI	;	rjmp EXT_INT0 ; IRQ0 Handler
RETI	;	rjmp PCINT0 ; PCINT0 Handler
RETI	;	rjmp TIM0_OVF ; Timer0 Overflow Handler
RETI	;	rjmp EE_RDY ; EEPROM Ready Handler
RETI	;	rjmp ANA_COMP ; Analog Comparator Handle
RETI	;	rjmp TIM0_COMPA ; Timer0 CompareA Handler
RETI	;	rjmp TIM0_COMPB ; Timer0 CompareB Handler
RETI	;	rjmp WATCHDOG ; Watchdog Interrupt Handl
RETI	;	rjmp ADC ; ADC Conversion Handler

;----------------------------------------------------------;
; Initialize

RESET:
	outi	SPL,low(RAMEND)		;
;	outi	SPH,high(RAMEND)	;
	outi	DDRB, (1<<led1)|(1<<led2)|(1<<led3)
	outi	PORTB, 0xff			; Pullup		


;----------------------------------------------------------;
; Main loop

main:
;rcall	SearchOneWire
	rcall	ReadOneWire

	rjmp	main

.MACRO OW_cmd
	ldi r16,@0 
	rcall	OWWriteByte
.ENDMACRO


;----------------------------------------------------------;
; Read temperature from _all_ connected devices, and read first result
ReadOneWire:
	rcall	OWReset

	// ��������� ������� ����������
//	in		r16, PINB
//	ori		r16, (1<<led)
//	bld		r16, led		; ��������� �� T � led ��� (���� ��� ����� 0), �� ���������� �� i2c ���� � �������� ����
//	out		PORTB, r16

	OW_cmd	0xCC			; ���������� �� �����
	OW_cmd	0x44			; dallas - measure

	ldi		r16, 100
	rcall	WaitMiliseconds

	rcall	OWReset

//	OW_cmd	0x55			; ���������� � �����������
//	rcall	OWSendROM_NO	; ����� �����������
	OW_cmd	0xCC			; ���������� �� �����

    OW_cmd	0xBE			; ������ ������

read_temp_onewire:			; ������ � ����������� �����������
	rcall	OWReadByte		; ������� ���� HI - ������� ������� �����, LO - �������
	mov		r17, r16		
	rcall	OWReadByte		; ������� ���� LO - ������� ������� �����
	cpi		r16, 0x08			; �������� �� ���������������
	brlo	temp_up_zerro	; ���� ���� - ������
	; ��� ���� ������� �������������� �� ������������ ����
	andi	r16, 0x07		; ���� ������ ������� ���� ����� (��� �� ���������)
temp_up_zerro:
	andi	r17, 0xf0		; HI(R17) = ������� ����� �����������
	or		r17, r16		; HI(R17)- �������, LO(R17) - �������
	swap	r17				; ������ ��� �� ����� ������

	sbi		PORTB, led1		; turn off
	sbi		PORTB, led2		; turn off
	sbi		PORTB, led3		; turn off

	cpi		r17, 50
	brlo	less50
	cbi		PORTB, led3		; hi temp
	ret
less50:
	cpi		r17, 40
	brlo	less40	
	cbi		PORTB, led2
	ret
less40:
	cpi		r17, 30
	brlo	less30	
	cbi		PORTB, led1
	ret
less30:
	ret

.include "1-wire.asm"
