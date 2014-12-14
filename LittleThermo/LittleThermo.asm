/*
 * LittleThermo.asm
 *
 *  Created: 16.10.2014 16:14:39
 *   Author: vlad
 */ 

 .include "avr.inc"

.EQU	l_green = PB0
.EQU	l_blue = PB1
.EQU	l_red = PB2

//#define	F_CPU 8000000
#define	F_CPU 9600000

;----------------------------------------------------------;
; Data memory area

.dseg
.ORG	RAMTOP

;.EQU	MaxInputSize	=	32
;LineBuf:.byte	MaxInputSize	;Command line characters buffer 
;ByteBuf:.byte	MaxInputSize/2  ;Command line bytes buffer

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
	outi	DDRB, (1<<l_green)|(1<<l_blue)|(1<<l_red)
	outi	PORTB, 0xff			; Pullup		

	ldi		R25,0				; flashing flag

;----------------------------------------------------------;
; Main loop

main:
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

// индикация наличия устройства
//	in		r16, PINB
//	ori		r16, (1<<led)
//	bld		r16, led		; загрузить из T в led бит (если бит равен 0), то устройство на i2c есть и зажигаем диод
//	out		PORTB, r16

	OW_cmd	0xCC			; адресуемся ко всему
	OW_cmd	0x44			; dallas - measure

	ldi		r16, 200
	rcall	WaitMiliseconds

	rcall	OWReset

//	OW_cmd	0x55			; адресуемся к конкретному
//	rcall	OWSendROM_NO	; адрес конкретного
	OW_cmd	0xCC			; адресуемся ко всему

    OW_cmd	0xBE			; читаем память

read_temp_onewire:			; читаем и преобразуем температуру
	rcall	OWReadByte		; младший байт HI - младшие разряды целых, LO - десятые
	mov		r17, r16		
	rcall	OWReadByte		; старший байт LO - старшие разряды целых
	cpi		r16, 0x08			; проверям на отрицательность
	brlo	temp_up_zerro	; выше нуля - уходим
//; тут надо сделать преобразование из дополненного кода, но пока упростим
	andi	r16, 0x07		; просто отсечем биты знака (что не правильно) и возьмем целую часть

temp_up_zerro:
	andi	r17, 0xf0		; HI(R17) = младшие знаки температуры
	or		r17, r16		; HI(R17)- младшие, LO(R17) - старшие
	swap	r17				; теперь все на своих местах

	sbi		PORTB, l_blue	; turn off blue
	sbi		PORTB, l_green	; turn off green
	sbi		PORTB, l_red	; turn off red

rjmp less35
	cpi		r17, 39			; >39 ultra high, flash red
	brlo	less39

	com		r25				; flip flash status
	brne	flash1
	cbi		PORTB, l_red		
	ret
flash1:
	sbi		PORTB, l_red
	ret
less39:						; 38-39 high
	cpi		r17, 38
	brlo	less38
	cbi		PORTB, l_red	
	ret
less38:						; 37-38 raised
	cpi		r17, 37
	brlo	less37	
	com		r25				; flip flash status
	brne	flash2
	cbi		PORTB, l_red
	ret
flash2:	
	cbi		PORTB, l_green	
	ret
less37:						; 36-37 normal
	cpi		r17, 36
	brlo	less36	
	cbi		PORTB, l_green		
	ret
less36:						; 35-36 low
	cpi		r17, 35
	brlo	less35	
	cbi		PORTB, l_blue		
	ret
less35:						; <35 very low
	com		r25				; flip flash status
	brne	flash3
	cbi		PORTB, l_blue
	ret
flash3:	
	sbi		PORTB, l_blue	
	ret

.include "1-wire.asm"
