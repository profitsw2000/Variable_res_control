;
; Variable_res_control.asm
;
/*
Формирование импульсов для управления переменным резистором AD8402. Назначение выводов: PORTB5 - SDI, PORTB7 - SCK, PORTB4 - CS.
Генерация импульсов начинается в момент нажатия кнопок (кнопки подключены к порту В). Одно нажатие кнопки формирует один пакет импульсов.
*/
; Created: 11.12.2018 14:44:55
; Author : Анализатор спектра
;

.equ	RBP				=	0
.equ	LBP				=	1

.def	reg_0			=	r0
.def	templ			=	r16
.def	temph			=	r17
.def	state_flag		=	r18
.def	right_but_state	=	r19
.def	left_but_state	=	r20
.def	button			=	r21
.def	shift_reg_h		=	r22
.def	shift_reg_l		=	r23
.def	count			=	r24

.org	0
rjmp	reset
.org	OVF2addr
jmp		Timer2
.org	OVF0addr
jmp		Timer0

reset:
//настройка стека
ldi		templ,LOW(RAMEND)
ldi		temph,HIGH(RAMEND)
out		SPL,templ
out		SPH,temph
//настройка таймера 0 и 2
ldi		templ,(1<<CS01)
out		TCCR0,templ
ldi		templ,(1<<TOIE0) | (1<<TOIE2)
out		TIMSK,templ
//настройка портов ВВ
ldi		templ,(1<<5) | (1<<7)
out		DDRB,templ
ldi		templ,3
out		PORTA,templ
;debug
ldi		templ,0xFF
out		DDRC,templ
;debug
//инициализация начальных значений регистров
clr		state_flag
clr		shift_reg_h
clr		shift_reg_l
ser		right_but_state
ser		left_but_state
ldi		button,0xF
//глобальное включение прерываний
sei

//главный цикл
main:
;debug
out		PORTC,state_flag
;debug
//проверка флагов нажатия кнопок
	sbrc	state_flag,RBP
	jmp		check_right_button_off
	sbrc	state_flag,LBP
	jmp		check_left_button_off
//проверка на нулевое значение регистра сдвига кнопок 
	cpi		right_but_state,0
	brne	check_left_button_state
	sbr		state_flag,(1<<RBP)
	ldi		templ,0
	inc		button
	jmp		set_shift_registers
check_left_button_state:
	cpi		left_but_state,0
	brne	main
	sbr		state_flag,(1<<LBP)
	ldi		templ,1
	dec		button
	jmp		set_shift_registers
//проверка на значение 0xFF регистра сдвига кнопок
check_right_button_off:
	cpi		right_but_state,0xFF
	brne	main
	cbr		state_flag,(1<<RBP)
	jmp		main
check_left_button_off:
	cpi		left_but_state,0xFF
	brne	main
	cbr		state_flag,(1<<LBP)
	jmp		main
//установка значений регистров сдвига переменного регистра
set_shift_registers:
	mov		shift_reg_h,button
	clr		shift_reg_l
	lsr		templ
	ror		shift_reg_h
	ror		shift_reg_l
	lsr		templ
	ror		shift_reg_h
	ror		shift_reg_l
	call	Timer2_ON
jmp		main
	
Timer2_ON:
	ldi		templ,(1<<CS21)
	out		TCCR2,templ
ret

Timer2_OFF:
	clr		templ
	out		TCCR2,templ
ret

Timer0:
//сохранение значений общих регистров, используемых в прерывании, в стек
	push	templ
	push	temph
	in		templ,SREG
	push	templ
//считывание значения на входе порта
	in		templ,PINA
	andi	templ,3
	mov		temph,templ
//сдвиг считаного значения в регистры сдвига кнопок
	ror		templ
	ror		right_but_state
	lsr		temph
	ror		temph
	ror		left_but_state

//восстановление значений общих регистров, сохраненных в стеке, перед выходом из прерывания
	pop		templ
	out		SREG,templ
	pop		temph
	pop		templ
reti

Timer2:
//сохранение значений общих регистров, используемых в прерывании, в стек
	push	templ
	push	temph
	in		templ,SREG
	push	templ
	
//проверка на четность/нечетность регистра счетчика
	sbrc	count,0
	rjmp	set_clk_high
//установка состояния линии SDI в зависимости от значения 7-го бита регистра сдвига и уставка в 0 линии CLK
	sbrc	shift_reg_h,7
	rjmp	set_sdi_high
	cbi		PORTB,5
	jmp		set_clk_low
set_sdi_high:
	sbi		PORTB,5
set_clk_low:
	cbi		PORTB,7
	rol		shift_reg_l
	rol		shift_reg_h
	rjmp	inc_count_reg
//установка лог. 1 на линии CLK
set_clk_high:
	sbi		PORTB,7	
//проверка значения count для определения конца пакета данных
inc_count_reg:
	inc		count
	cpi		count,21
	brlo	exit_timer_2
	clr		count
	call	Timer2_OFF
exit_timer_2:
//восстановление значений общих регистров, сохраненных в стеке, перед выходом из прерывания
	pop		templ
	out		SREG,templ
	pop		temph
	pop		templ
reti
