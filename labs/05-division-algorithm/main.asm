.include "m168Adef.inc"

.def dividend  = r16
.def divisor   = r17
.def quotient  = r18
.def remainder = r19
.def counter   = r20
.def temp      = r21

.org 0x0000
    rjmp    main

main:
    ldi     temp, HIGH(RAMEND)
    out     SPH, temp
    ldi     temp, LOW(RAMEND)
    out     SPL, temp

    ldi     dividend, 100
    ldi     divisor, 7

    rcall   div8u

done:
    rjmp    done

div8u:
    tst     divisor
    breq    div_by_zero

    clr     remainder
    clr     quotient
    ldi     counter, 8

div_loop:
    lsl     dividend
    rol     remainder

    cp      remainder, divisor
    brlo    div_next

    sub     remainder, divisor
    sec
    rjmp    div_store_bit

div_next:
    clc

div_store_bit:
    rol     quotient

    dec     counter
    brne    div_loop

    ret

div_by_zero:
    ldi     quotient,  0xFF
    ldi     remainder, 0xFF
    ret
