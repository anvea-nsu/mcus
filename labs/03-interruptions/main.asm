.include "m168Adef.inc"

.org 0x0000
    rjmp main

.org 0x0020
    rjmp TIMER0_OVF

main:
    cli

    ldi r16, 0b00000000         
    out TCCR0A, r16

    ldi r16, 0b00000001
    out TCCR0B, r16

    ldi r16, 0
    out OCR0A, r16
    out OCR0B, r16

    ldi r16, 0b00000001
    sts TIMSK0, r16

    ldi r16, 0
    out TCNT0, r16

    ldi r20, 0

    sei

loop:
    rjmp loop

TIMER0_OVF:
    push r16
    in r16, SREG
    push r16

    inc r20

    pop r16
    out SREG, r16
    pop r16

    reti
