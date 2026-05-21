.include "m168Adef.inc"

.equ LO          = 0b00000000
.equ HI          = 0b11111111
.equ SEG_MASK    = 0b01111111
.equ ROW_MASK    = 0b00001111
.equ COL_MASK    = 0b00000111
.equ SCAN_ROW1   = 0b00001110
.equ SCAN_ROW2   = 0b00001101
.equ SCAN_ROW3   = 0b00001011
.equ SCAN_ROW4   = 0b00000111
.equ NO_KEY      = 0xFF

.CSEG
.ORG 0x0000
    rjmp RESET
.ORG PCI1addr
    rjmp PCINT1_ISR

.ORG INT_VECTORS_SIZE
RESET:
    ldi  r16, HIGH(RAMEND)
    out  SPH, r16
    ldi  r16, LOW(RAMEND)
    out  SPL, r16

    ldi  r16, SEG_MASK
    out  DDRD, r16
    ldi  r16, LO
    out  PORTD, r16

    ldi  r16, ROW_MASK
    out  DDRB, r16
    ldi  r16, LO
    out  PORTB, r16

    ldi  r16, LO
    out  DDRC, r16
    ldi  r16, COL_MASK
    out  PORTC, r16

    ldi  r16, (1 << PCINT8) | (1 << PCINT9) | (1 << PCINT10)
    sts  PCMSK1, r16
 
    ldi  r16, (1 << PCIE1)
    sts  PCICR, r16
 
    sei

MAIN_LOOP:
    rjmp MAIN_LOOP


PCINT1_ISR:
    push r16
    in   r16, SREG
    push r16
    push r17
    push r20
    push ZL
    push ZH
 
    in   r17, PINC
    andi r17, COL_MASK
    cpi  r17, COL_MASK
    breq ISR_RESTORE
 
    ldi  r16, SCAN_ROW1
    out  PORTB, r16

    ldi  r20, NO_KEY
    in   r17, PINC
    sbrs r17, 0
    ldi  r20, 1
    sbrs r17, 1
    ldi  r20, 2
    sbrs r17, 2
    ldi  r20, 3
 
    ldi  r16, SCAN_ROW2
    out  PORTB, r16

    in   r17, PINC
    sbrs r17, 0
    ldi  r20, 4
    sbrs r17, 1
    ldi  r20, 5
    sbrs r17, 2
    ldi  r20, 6

    ldi  r16, SCAN_ROW3
    out  PORTB, r16

    in   r17, PINC
    sbrs r17, 0
    ldi  r20, 7
    sbrs r17, 1
    ldi  r20, 8
    sbrs r17, 2
    ldi  r20, 9

    ldi  r16, SCAN_ROW4
    out  PORTB, r16

    in   r17, PINC
    sbrs r17, 0
    ldi  r20, 10
    sbrs r17, 1
    ldi  r20, 0
    sbrs r17, 2
    ldi  r20, 11

    cpi  r20, NO_KEY
    breq ISR_RESTORE

    ldi  ZH, HIGH(SEG_TABLE * 2)
    ldi  ZL, LOW(SEG_TABLE * 2)
    add  ZL, r20
    clr  r16
    adc  ZH, r16
    lpm  r16, Z
    out  PORTD, r16
 
ISR_RESTORE:
    ldi  r16, LO
    out  PORTB, r16

    ldi  r16, (1 << PCIF1)
    out  PCIFR, r16

    pop  ZH
    pop  ZL
    pop  r20
    pop  r17
    pop  r16
    out  SREG, r16
    pop  r16
    reti

SEG_TABLE:
    ;    0     1     2     3     4     5     6     7     8     9     *     #
    .db  0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0x00, 0x00

.DSEG
.ORG SRAM_START

