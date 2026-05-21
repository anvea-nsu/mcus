.include "m168Adef.inc"

.org 0x0000
    rjmp MAIN

MAIN:
    ldi r16, 5
    ldi r17, 3
    add r16, r17

    inc r16

    sub r16, r17

    dec r16

    sts 0x0100, r16
    lds r18, 0x0100

LOOP:
    rjmp LOOP
