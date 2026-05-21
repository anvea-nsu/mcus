.include "m168Adef.inc"

.org 0x00
    rjmp MAIN

MAIN:
    ldi r16, HIGH(RAMEND)
    out SPH, r16
    ldi r16, LOW(RAMEND)
    out SPL, r16

    sbi DDRD, 6

    ldi r16, (1 << COM0A1) | (1 << WGM01) | (1 << WGM00)
    out TCCR0A, r16

    ldi r16, (1<< CS01)
    out TCCR0B, r16

    ldi r16, 0x7F
    out OCR0A, r16

LOOP:
    rjmp LOOP
