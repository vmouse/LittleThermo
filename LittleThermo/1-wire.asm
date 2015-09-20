;------------------------------------------------------------------------------
; http://avr-mcu.dxp.pl
; (c) Radoslaw Kwiecien, 2008
; 
; Перевод StarXXX, http://hardisoft.ru, 2009
;------------------------------------------------------------------------------



;------------------------------------------------------------------------------
; Начальные установки для реализации протокола 1-Wire
;------------------------------------------------------------------------------
.equ	OW_PORT	= PORTB				; Порт МК, где висит 1-Wire
.equ	OW_PIN	= PINB				; Порт МК, где висит 1-Wire
.equ	OW_DDR	= DDRB				; Порт МК, где висит 1-Wire
.equ	OW_DQ	= PB4				; Ножка порта, где висит 1-Wire

.def	OWCount = r17				; Счетчик
;------------------------------------------------------------------------------


.cseg

.include 	"wait.asm"			; Подключаем модуль временных задержек

;------------------------------------------------------------------------------
; СБРОС
; Каждая передача по протоколу 1-Wire начинается с сигнала Reset.
; После вызова этой процедуры в флаге Т регистра SGER содержится бит 
; присутствия: 1 - если на шине нет устройств, 0 - если есть
;------------------------------------------------------------------------------
; Output : T - presence bit
;------------------------------------------------------------------------------
OWReset:
	cbi		OW_PORT,OW_DQ		; Выводим в порт 0
	sbi		OW_DDR,OW_DQ		; Переключаем порт на вывод

	ldi		XH, HIGH(DVUS(470))	; Ждем 470 микросекунд при придавленной в 0 линии. Это и есть импульс сброса.
	ldi		XL, LOW(DVUS(470))
	rcall		Wait4xCycles
	
	cbi		OW_DDR,OW_DQ		; Переключаем порт на ввод

	ldi		XH, HIGH(DVUS(70))	; выжидаем 70 мкс (необходимое минимальное время реакции устройств на сброс)
	ldi		XL, LOW(DVUS(70))
	rcall		Wait4xCycles

	set							; Устанавливаем флаг Т в 1
	sbis	OW_PIN,OW_DQ		; Если на линии после паузы осталась 1, значит устройств 1-Wire на ней нет. Пропускаем след. команду
	clt							; Линия была в 0 - значит на ней кто-то есть, и ответил нам импульсом PRESENCE

	ldi		XH, HIGH(DVUS(240))	; Пауза 240 мкс после сброса
	ldi		XL, LOW(DVUS(240))
	rcall		Wait4xCycles

	ret


;------------------------------------------------------------------------------
; ОТПРАВКА 1 БИТА
; Эта процедура отправляет 1 бит в линию 1-Wire.
; Отправляемый бит должен быть помещен в флаг С статусного регистра
;------------------------------------------------------------------------------
; Input : C - bit to write
;------------------------------------------------------------------------------
OWWriteBit:
	brcc	OWWriteZero			; Если флаг С = 0, то переход на OWWriteZero
	ldi		XH, HIGH(DVUS(1))	; Для посылки 1 линию нужно придавить в 0 всего на 1 мкс
	ldi		XL, LOW(DVUS(1))
	rjmp	OWWriteOne			; переходим к отправке
OWWriteZero:	
	ldi		XH, HIGH(DVUS(120))	; Для посылки 0 линию нужно придавить в 0 на 120 мкс
	ldi		XL, LOW(DVUS(120))
OWWriteOne:
	sbi		OW_DDR, OW_DQ		; Переводим порт на выход, а там уже был 0, соответственно и линия придавливается в 0
	rcall	Wait4xCycles		; ждем
	cbi		OW_DDR, OW_DQ		; Переводим порт на вход
	
	ldi		XH, HIGH(DVUS(60))	; Должна быть пауза между таймслотами, вообще-то от 1 мкс, но здесь сделали 60 мкс
	ldi		XL, LOW(DVUS(60))
	rcall	Wait4xCycles
	ret


;------------------------------------------------------------------------------
; ОТПРАВКА 1 БАЙТА
; Эта процедура отправляет 1 байт в линию 1-Wire.
; Отправляемый байт должен быть помещен в регистр r16
;------------------------------------------------------------------------------
; Input : r16 - byte to write
;X,r16 - broken!
;------------------------------------------------------------------------------
OWWriteByte:
	push	OWCount			; Сохраняем регистр счетчика
	ldi		OWCount,0		; Взводим в нём нолик

OWWriteLoop:				
	ror		r16				; Сдвигаем байт вправо через флаг C
	rcall	OWWriteBit		; отправляем в линию
	inc		OWCount			; увеличиваем счетчик
	cpi		OWCount,8		; проверяем на 8
	brne	OWWriteLoop		; если меньше - следующий бит
	pop		OWCount			; восстанавливаем регистр-счетчик
	ret



;------------------------------------------------------------------------------
; ЧТЕНИЕ 1 БИТА
; Эта процедура читает 1 бит из линии 1-Wire.
; Принятый бит помещается в флаг С статусного регистра
;------------------------------------------------------------------------------
; Output : C - bit from slave
;------------------------------------------------------------------------------
OWReadBit:
	ldi		XH, HIGH(DVUS(1))	; Придавливаем линию в 0 на 1 мкс
	ldi		XL, LOW(DVUS(1))
	sbi		OW_DDR, OW_DQ
	rcall	Wait4xCycles

	cbi		OW_DDR, OW_DQ		; Переводим порт на чтение
	ldi		XH, HIGH(DVUS(5))	; ждем 5 мкс
	ldi		XL, LOW(DVUS(5))
	rcall	Wait4xCycles

	clt							; Сбрасываем флаг Т
	sbic	OW_PIN,OW_DQ		; Если на линии 0 - то пропускаем следующую команду
	set

								; Итак, сейчас в регистре Т полученный бит

	ldi		XH, HIGH(DVUS(50))	; выжидаем 50 мкс для окончания таймслота
	ldi		XL, LOW(DVUS(50))
	rcall	Wait4xCycles
								; переносим флаг Т в флаг С
	sec
	brts	OWReadBitEnd
	clc

OWReadBitEnd:
	ret



;------------------------------------------------------------------------------
; ЧТЕНИЕ 1 БАЙТА
; Эта процедура читает 1 байт из линии 1-Wire.
; Принятый байт помещается регистр r16
;------------------------------------------------------------------------------
; Output : r16 - byte from slave
;------------------------------------------------------------------------------
OWReadByte:
	push	OWCount			; Сохраняем регистр-счетчик
	ldi		OWCount,0		; и обнуляем его
OWReadLoop:
	rcall	OWReadBit		; читаем бит
	ror		r16				; запихиваем его в r16 сдвигом вправо из флага С
	inc		OWCount			; увеличиваем счетчик
	cpi		OWCount,8		; уже 8?
	brne	OWReadLoop		; нет - продолжаем считывать
	pop		OWCount			; восстанавливаем регистр-счетчик
	ret
;------------------------------------------------------------------------------
;
;------------------------------------------------------------------------------


//.include 	"1-Wire Search.asm"		; Подключаем модуль поиска устройств на шине 1-Wire




