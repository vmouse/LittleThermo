;***********************************************************************************
; Поиск устройств на шине 1-Wire
; Оригинал: Application Note 187. 1-Wire Search Algorithm by Dallas, С code
; портировано на ассемблер: StarXXX, http://hardisoft.ru (c) 2009
;***********************************************************************************
; Порядок использования:
;	1) Очистить ROM_NO вызовом подпрограммы OWClearROM_NO
;	2) Произвести первый поиск вызовом подпрограммы OWFirst
;	3) если флаг search_result в регистре search_flags = 1 тогда сохранить 
;		найденный код ПЗУ из ROM_NO, произвести следующий поиск вызовом 
;		подпрограммы OWNext и перейти к пункту 3
;
; Используемые регистры: r16, r17, r20 (search_flags)
;
; 
; Поиск использует внешние подпрограммы:
;
;	OWReset - Выполняет сброс линии 1-Wire, принимает от устройств импульс
;			присутствия PRESENCE. После вызова этой процедуры в флаге Т регистра 
;			SREG содержится бит присутствия: 1 - если на шине нет устройств, 
;			0 - если есть
;
;	OWWriteByte - Эта процедура отправляет 1 байт в линию 1-Wire. Отправляемый 
;			байт должен быть помещен в регистр r16
;	
;	OWReadBit - Эта процедура читает 1 бит из линии 1-Wire. Принятый бит 
;			помещается в флаг С регистра SREG
;
;	OWWriteBit - Эта процедура отправляет 1 бит в линию 1-Wire. Отправляемый 
;			бит должен быть помещен в флаг С регистра SREG
;
;***********************************************************************************


; Флаги
.equ		search_result		= 0
.equ		search_direction 	= 1
.equ		LastDeviceFlag		= 2

; Регистры
.def		search_flags		= r20


;------------------------------------------------------------------------------
; Поиск первого устройства на шине
;------------------------------------------------------------------------------
OWFirst:
    ; обнуление переменных
	clr		r16
	sts		LastDiscrepancy, r16
	sts		LastFamilyDiscrepancy, r16
	sts		stored_search_flags, r16

   	rcall 	OWNext
	ret


;------------------------------------------------------------------------------
; Поиск следующего устройства на шине
;------------------------------------------------------------------------------
OWNext:
	lds		search_flags, stored_search_flags	; Восстанавливаем флаги предыдущего поиска

   	clr 	r16
   	sts 	last_zero, r16						; last_zero = 0
   	sts 	rom_byte_number, r16				; rom_byte_number = 0
   	sts 	crc8, r16							; crc8 = 0

   	inc 	r16
   	sts 	id_bit_number, r16					; id_bit_number = 1
   	sts 	rom_byte_mask, r16					; rom_byte_mask = 1

	cbr		search_flags, 1<<search_result		; search_result = FALSE

	sbrc	search_flags, LastDeviceFlag		; Это было последнее устройство?
	rjmp 	OWSItWasLastDevice					; Да - переходим на OWSItWasLastDevice


OWS_Reset:										; Сброс линии и проверка присутствия
	rcall 	OWReset
	brtc 	OWSResetOK
												; Никого нет? Тогда выходим
	clr 	r16
	sts 	LastDiscrepancy, r16				; LastDiscrepancy = 0;
	sts 	LastFamilyDiscrepancy, r16			; LastFamilyDiscrepancy = 0;
	cbr		search_flags, 1<<LastDeviceFlag		; LastDeviceFlag = FALSE;
	cbr		search_flags, 1<<search_result		; return FALSE;

	rjmp	OWN_Return


OWSResetOK:
	ldi 	r16, 0xF0							; Посылаем команду поиска (0F)
	cli
	rcall 	OWWriteByte
	sei


OWS_do:											; Основной цикл поиска
	clr 	r16
	clr 	r17
	sbr		search_flags, 1<<search_direction	; Сразу поставим search_direction=1, потом если что - сбросим
	
	cli
	rcall 	OWReadBit							; читаем id_bit -> C
	rol 	r16									; из флага C в нулевой бит r16

	rcall 	OWReadBit							; читаем cmp_id_bit -> C
	rol 	r17									; из флага C в нулевой бит r17
	sei

	tst 	r16
	breq 	OWS_do_1_0

	tst 	r17
	breq 	OWS_do_1_1
	rjmp 	OWS_do_break						; id_bit = 1 и cmp_id_bit = 1 - на линии нет устройств!


OWS_do_1_0:
	cbr		search_flags, 1<<search_direction	; search_direction пока повторяет id_bit


OWS_do_1_1:										;  если id_bit не равен cmp_id_bit, тогда search_direction = id_bit
	cp 		r16, r17
	brne 	OWS_do_2

	; Иначе - биты равны, тогда search_direction будет зависеть от id_bit_number и LastDiscrepancy
	
	sbr		search_flags, 1<<search_direction	; установим пока search_direction = 1

	lds 	r16, id_bit_number					; загружаем для проверки id_bit_number и LastDiscrepancy
	lds		r17, LastDiscrepancy

	cp 		r16, r17							; сравниваем
	breq	BitsEqual_End						; id_bit_number = LastDiscrepancy, значит оставляем search_direction = 1
	brcc	OWS_do_BitsEqual_else				; id_bit_number > LastDiscrepancy, значит установим search_direction = 0

	; иначе id_bit_number < LastDiscrepancy, а это значит, что search_direction будет равен
	; значению текущего бита в ROM_NO
				
	rcall	Calc_ROM_NO							; Получаем указатель на ROM_NO[rom_byte_number]
	ld		r16, y								; Получили в r16 ROM_NO[rom_byte_number]
	lds		r17, rom_byte_mask					; Делаем ROM_NO[rom_byte_number] AND rom_byte_mask
	and		r16, r17

	brne	BitsEqual_End						; если после AND результат не нулевой, то оставим search_direction = 1
	cbr		search_flags, 1<<search_direction	; иначе переключим search_direction в 0
	rjmp 	BitsEqual_End


OWS_do_BitsEqual_else:							; id_bit_number = LastDiscrepancy, значит оставляем search_direction = 1
	cbr		search_flags, 1<<search_direction


BitsEqual_End:
	sbrc	search_flags, search_direction		; если search_direction = 0,
	rjmp 	OWS_do_2

	lds 	r16, id_bit_number					; тогда last_zero = id_bit_number
	sts 	last_zero, r16

	; проверка последнего различия в коде семейства.
	cpi 	r16, 9								; Если last_zero < 9
	brcc 	OWS_do_2

	sts 	LastFamilyDiscrepancy, r16  		; тогда LastFamilyDiscrepancy = last_zero;


OWS_do_2:
	rcall	Calc_ROM_NO							; Получаем указатель на ROM_NO[rom_byte_number]

	; Устанавливаем или сбрасываем бит в позиции rom_byte_mask байта rom_byte_number
	; в зависимости от search_direction

	sbrs	search_flags, search_direction		;если search_direction = 1
	rjmp	OWS_do_2_1

	; Тогда, устанавливаем бит в 1: ROM_NO[rom_byte_number] = ROM_NO[rom_byte_number] OR rom_byte_mask;

	ld 		r16, y								; Получили в r16 ROM_NO[rom_byte_number]
	lds		r17, rom_byte_mask					; получили в r17 rom_byte_mask
	or 		r16, r17							; сделали ROM_NO[rom_byte_number] OR rom_byte_mask
	
	rjmp 	OWS_do_2_2

			
OWS_do_2_1:										
	; иначе search_direction = 1
	; Тогда сбрасываем бит в 0: ROM_NO[rom_byte_number] = ROM_NO[rom_byte_number] AND (rom_byte_mask XOR FF);
	lds		r17, rom_byte_mask					; получили в r17 rom_byte_mask
	ldi		r16, 0xFF
	EOR		R17, R16							; инвертировали R17

	ld 		r16, y								; Получили в r16 ROM_NO[rom_byte_number]
	AND		r16, r17							; сделали ROM_NO[rom_byte_number] AND (rom_byte_mask XOR FF)


OWS_do_2_2:
	ST 		y, r16								; записали назад в ROM_NO[rom_byte_number]

	sec											; отсылаем бит search_direction в шину, чтобы заткнуть те устройства, у которых этот бит не такой
	sbrs	search_flags, search_direction		
	clc
	cli
	rcall 	OWWriteBit							
	sei

	lds 	r16, id_bit_number					; id_bit_number++;
	inc 	r16
	sts 	id_bit_number, r16

	lds 	r16, rom_byte_mask					; Сдвигаем влево rom_byte_mask на 1 бит
	lsl 	r16
	sts 	rom_byte_mask, r16
	brne 	OWS_do_end							; если еще не все биты в текущем байте прошли - то бегом на следующую итерацию цикла поиска

	; иначе добавляем CRC этого байта в общее CRC

	rcall	Calc_ROM_NO							; Получаем указатель на ROM_NO[rom_byte_number]
	ld		r16, y								; Получили в r16 ROM_NO[rom_byte_number]

	rcall 	docrc8								; CRC готова

	lds 	r16, rom_byte_number				; rom_byte_number = rom_byte_number+1;
	inc 	r16
	sts 	rom_byte_number, r16

	ldi 	r16, 1								; Сбрасываем битовую маску в 1
	sts 	rom_byte_mask, r16


OWS_do_end:										; Крутим цикл пока rom_byte_number < 8
	lds 	r16, rom_byte_number
	cpi 	r16, 8
	brcc 	OWS_do_break
	rjmp 	OWS_do


	; если поиск прошел успешно, тогда id_bit_number будет больше 64 и crc8 будет равна 0
OWS_do_break:
	lds 	r16, id_bit_number
	cpi 	r16, 65
	brcc 	OWS_bo_break_0
	rjmp 	OWSItWasLastDevice					; id_bit_number < 65, ошибка!


OWS_bo_break_0:
	lds 	r16, crc8
	tst 	r16
	breq 	OWS_bo_break_00
	rjmp 	OWSItWasLastDevice					; crc8 не равно 0, ошибка!


OWS_bo_break_00:
	; Поиск удался, установим флаги и переменные
	lds 	r16, last_zero						; LastDiscrepancy = last_zero;
	sts 	LastDiscrepancy, r16

	tst		r16									; если LastDiscrepancy = 0
	brne 	OWS_do_break_1

	sbr		search_flags, 1<<LastDeviceFlag		; то это был последний девайс на линии, LastDeviceFlag = 1


OWS_do_break_1:
	lds		r16, LastFamilyDiscrepancy
	lds		r17, LastDiscrepancy
	cp		r16,r17								; если LastFamilyDiscrepancy == LastDiscrepancy
	brne	OWS_do_break_2

	clr 	r16
	sts		LastFamilyDiscrepancy, r16			; то LastFamilyDiscrepancy = 0


OWS_do_break_2:
	sbr		search_flags, 1<<search_result		; search_result = 1, ура, все ОК!
	rjmp	OWN_Return


OWSItWasLastDevice:
	sbrc	search_flags, search_result			; если search_result = 0
	rjmp	OWN_Return

	lds		r16, ROM_NO
	tst 	r16
	brne 	OWN_Return
	
	; Тогда сбрасываем флаги и переменные так, чтобы следующий вызов этой подпрограммы был равносилем вызову OWFirst
	cbr		search_flags, LastDeviceFlag		; LastDeviceFlag = 0
	clr 	r16
	sts 	LastDiscrepancy, r16				; LastDiscrepancy = 0	
	sts 	LastFamilyDiscrepancy, r16			; LastFamilyDiscrepancy = 0
	cbr		search_flags, 1<<search_result		; search_result = 0


OWN_Return:
	sts		stored_search_flags, search_flags	; Сохраняем флаги для следующего поиска
	ret





;*********************************************************************		
; 	Вычисляем указатель на ROM_NO[rom_byte_number]
;

calc_ROM_NO:
	ldi		yh, high(ROM_NO)					; указатель на ROM_NO
	ldi		yl, low (ROM_NO)
	lds		r16, rom_byte_number				; прибавляем к нему rom_byte_number
	clr		r17
	add		yl, r16
	adc		yh, r17
	ret





;*********************************************************************		
;   Очистка буфера ROM_NO
; 	
OWClearROM_NO:

	ldi yh, high(ROM_NO)			; указатель на ROM_NO
	ldi yl, low (ROM_NO)

	ldi r16, 8
	clr r17

OWCRN:
	st y+, r17
	dec r16
	brne OWCRN
			   
	ret


;*********************************************************************		
;   Отправляет буфер ROM_NO (для команды MATCH)
; 	
OWSendROM_NO:
	ldi yh, high(ROM_NO)			; указатель на ROM_NO
	ldi yl, low (ROM_NO)
	ldi r17, 8						;счетчик байт

OWSNDRN:
	ld r16, y+
	rcall	OWWriteByte

	dec r17
	brne OWSNDRN
			   
	ret



;*********************************************************************		
;   выполняет подсчет CRC по алгоритму 1-Wire
; 	вход: r16 - считанный байт
; 	выход: CRC - содержит подсчитанную сумму
; 	портит: регистр Z
; 	примечание: перед первым вызовом CRC необходимо обнулить

docrc8:
	lds		r17, CRC8
	eor		r16, r17
	
	ldi		ZH, high(CRCtable)
	ldi		ZL, low(CRCtable)
	clc
	rol		ZL
	rol		ZH
	add		ZL, r16
	ldi		r17,0
	adc		ZH, r17
	lpm		r16, z
	sts		CRC8, r16
	ret


CRCtable:
; таблица сигнатур для быстрого расчета контрольной суммы CRC-8
	.db		0, 94, 188, 226, 97, 63, 221, 131, 194, 156, 126, 32, 163, 253, 31, 65
	.db 	157, 195, 33, 127, 252, 162, 64, 30, 95, 1, 227, 189, 62, 96, 130, 220
	.db 	35, 125, 159, 193, 66, 28, 254, 160, 225, 191, 93, 3, 128, 222, 60, 98
	.db 	190, 224, 2, 92, 223, 129, 99, 61, 124, 34, 192, 158, 29, 67, 161, 255
	.db 	70, 24, 250, 164, 39, 121, 155, 197, 132, 218, 56, 102, 229, 187, 89, 7
	.db 	219, 133, 103, 57, 186, 228, 6, 88, 25, 71, 165, 251, 120, 38, 196, 154
	.db 	101, 59, 217, 135, 4, 90, 184, 230, 167, 249, 27, 69, 198, 152, 122, 36
	.db 	248, 166, 68, 26, 153, 199, 37, 123, 58, 100, 134, 216, 91, 5, 231, 185
	.db 	140, 210, 48, 110, 237, 179, 81, 15, 78, 16, 242, 172, 47, 113, 147,205
	.db 	17, 79, 173, 243, 112, 46, 204, 146, 211, 141, 111, 49, 178, 236, 14, 80
	.db 	175, 241, 19, 77, 206, 144, 114, 44, 109, 51, 209, 143, 12, 82, 176, 238
	.db 	50, 108, 142, 208, 83, 13, 239, 177, 240, 174, 76, 18, 145, 207, 45, 115
	.db 	202, 148, 118, 40, 171, 245, 23, 73, 8, 86, 180, 234, 105, 55, 213, 139
	.db 	87, 9, 235, 181, 54, 104, 138, 212, 149, 203, 41, 119, 244, 170, 72, 22
	.db 	233, 183, 85, 11, 136, 214, 52, 106, 43, 117, 151, 201, 74, 20, 246, 168
	.db 	116, 42, 200, 150, 21, 75, 169, 247, 182, 232, 10, 84, 215, 137, 107, 53





; Переменные, необходимые для работы процедуры поиска
.dseg

stored_search_flags:	.db	0
id_bit_number: 			.db 0
rom_byte_number:		.db 0
rom_byte_mask:			.db 0
last_zero:				.db 0
LastDiscrepancy:		.db 0
LastFamilyDiscrepancy:	.db 0
crc8:					.db 0
ROM_NO:					.byte 8


.cseg
