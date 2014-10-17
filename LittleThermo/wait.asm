;------------------------------------------------------------------------------
; Busy-wait loops utilities module
; For F_CPU >= 4MHz
; http://avr-mcu.dxp.pl
; (c) Radoslaw Kwiecien, 2008
; 
; ������� StarXXX, http://hardisoft.ru, 2009
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; ������ ��������� ��������
;
; !!! ��� ������ ������ ���������� �������� ��������� F_CPU ������ �������� ������� � ������ !!!
;
; !!! �������� ������������� ��� �������� ������� >= 4 ��� !!!


; �������� ��������������! ��� ������ ��������, ��� ������,
; �.�. ��� ������� 4��� �������� � 1 ������������, �������� ����� ������ ������������ � �������� �� ��� �������� 2,5 ������������
; �������� � 10 ����������� �������� 11,5 �����������
; �������� � 100 ��� �� ����� ���� ����� 101,5 ���
; ������, � ������ �������� ��������� 1,5 ��� - ��� ����� �� ����� ������������ � �� ����� �� ���
;------------------------------------------------------------------------------



#ifndef F_CPU
	#error "F_CPU must be defined!"
#endif

#if F_CPU < 4000000
	#warning "F_CPU too low, possible wrong delay"
#endif


#define CYCLES_PER_US (F_CPU/1000000)	; ���������� ������ �� ������������
#define C4PUS (CYCLES_PER_US/4)		; 4 ����� �� ���� ������������
#define DVUS(x) (C4PUS*x)		; ��������� �������� ��� ���������� ������� � �������������, ������� ����� �������� Wait4xCycles ����� �������� �������� ��������

;--------------------------------------------------------------------------------------------------------------
; ������������ ��������. � ����� ���������� 4 ����� �� ������ ��������, ����� ���������. � ��������� - 3 �����.
; �����, ��� ��������� ������ �������� � ������������� ���� �������� ��� ������� ��������������
; ��������� �������� �������� DVUS:
;	ldi    XH, HIGH(DVUS(500))
; 	ldi    XL, LOW(DVUS(500))
; 	rcall  Wait4xCycles ; ����� 500 �����������
;--------------------------------------------------------------------------------------------------------------
; Input : XH:XL - number of CPU cycles to wait (divided by four)
;--------------------------------------------------------------------------------------------------------------
Wait4xCycles:
	sbiw	XH:XL, 1			; 2 �����
	brne	Wait4xCycles		; 1/2
	ret							; 4


;------------------------------------------------------------------------------
; ������������ ���������� ����������� �������� � ������������
; �� �����: r16 = ���������� ����������
;------------------------------------------------------------------------------
; Input : r16 - number of miliseconds to wait
;------------------------------------------------------------------------------
WaitMiliseconds:
	push 	r16
WaitMsLoop: 
	ldi    XH,HIGH(DVUS(500))
	ldi    XL,LOW(DVUS(500))
	rcall  Wait4xCycles
	ldi    XH,HIGH(DVUS(500))
	ldi    XL,LOW(DVUS(500))
	rcall  Wait4xCycles
	dec    r16
	brne   WaitMsLoop
	pop    r16
	ret
;------------------------------------------------------------------------------
; End of file
;------------------------------------------------------------------------------
