.include "m168Adef.inc"

.equ F_CPU     = 16000000
.equ PRESCALER = 256
.equ TIMER_TOP = (F_CPU / PRESCALER) - 1

.equ TIME_ON  = 1
.equ TIME_OFF = 2

.CSEG
.ORG 0x0000
    rjmp RESET
.ORG OC1Aaddr
    rjmp TIMER1_COMPA_ISR

.ORG INT_VECTORS_SIZE
RESET:
    ldi  r16, HIGH(RAMEND)
    out  SPH, r16
    ldi  r16, LOW(RAMEND)
    out  SPL, r16

    sbi  DDRB, PB5
    sbi  PORTB, PB5

    clr  r16
    sts  seconds, r16
    ldi  r16, 1
    sts  led_state, r16

    clr  r16
    sts  TCCR1A, r16

    ldi  r16, (1 << WGM12) | (1 << CS12)
    sts  TCCR1B, r16

    ldi  r16, HIGH(TIMER_TOP)
    sts  OCR1AH, r16
    ldi  r16, LOW(TIMER_TOP)
    sts  OCR1AL, r16

    ldi  r16, (1 << OCIE1A)
    sts  TIMSK1, r16

    sei

MAIN_LOOP:
    rjmp MAIN_LOOP

TIMER1_COMPA_ISR:
    push r16
    in   r16, SREG
    push r16
    push r17

    lds  r16, seconds
    inc  r16
    sts  seconds, r16

    lds  r17, led_state
    cpi  r17, 1
    brne CHECK_OFF
CHECK_ON:
    cpi  r16, TIME_ON
    brlo ISR_EXIT
    cbi  PORTB, PB5
    clr  r17
    sts  led_state, r17
    clr  r16
    sts  seconds, r16
    rjmp ISR_EXIT
CHECK_OFF:
    cpi  r16, TIME_OFF
    brlo ISR_EXIT
    sbi  PORTB, PB5
    ldi  r17, 1
    sts  led_state, r17
    clr  r16
    sts  seconds, r16
ISR_EXIT:
    pop  r17
    pop  r16
    out  SREG, r16
    pop  r16
    reti

.DSEG
.ORG SRAM_START
seconds: .db 1
led_state: .db 1

