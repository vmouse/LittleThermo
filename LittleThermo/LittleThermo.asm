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

	sbi		PORTB, led1		; turn off blue
	sbi		PORTB, led2		; turn off green
	sbi		PORTB, led3		; turn off red

	cpi		r17, 39
	brlo	less39

	in		r16, PORTB		; ultra high
	ldi		r18, (1<<led3)
	eor		r16, r18
	out		PORTB, r16		; flash bit led3
	ret
less39:
	cpi		r17, 38
	brlo	less38
	cbi		PORTB, led3		; high
	ret
less38:
	cpi		r17, 37
	brlo	less37	
	cbi		PORTB, led2		; raised
	cbi		PORTB, led3		; raised
	ret
less37:
	cpi		r17, 36
	brlo	less36	
	cbi		PORTB, led2		; normal
	ret
less36:
	cbi		PORTB, led1		; low
	ret

.include "1-wire.asm"
