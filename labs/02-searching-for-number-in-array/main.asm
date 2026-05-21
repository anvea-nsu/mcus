.include "m168Adef.inc"

.org 0x0000
    rjmp MAIN

MAIN:
    ldi r16, HIGH(RAMEND)
    out SPH, r16
    ldi r16, LOW(RAMEND)
    out SPL, r16

    ldi r16, 10

    ldi r26, LOW(0x0100)
    ldi r27, HIGH(0x0100)

INIT:
    ldi r17, 0
    ldi r18, 1

    rjmp DESIGNATE

DESIGNATE:
    cpi r17, 10
    brge FIND

    st X+, r18
    lsl r18

    inc r17
    rjmp DESIGNATE

FIND:
    ldi r17, 0

    ldi r19, 32 ; element for find is 32

    ldi r26, LOW(0x0100)
    ldi r27, HIGH(0x0100)

    rjmp LOOP

LOOP:
    cpi r17, 10
    brge FINISH

    ld r18, X+
    cp r18, r19
    breq SAVE

    inc r17
    rjmp LOOP

SAVE:
    mov r20, r17
    rjmp FINISH
  
FINISH:
    rjmp FINISH
