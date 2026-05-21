.include "m168Adef.inc"

.equ LO            = 0b00000000
.equ HI            = 0b11111111

.equ SS_BIT        = PB2
.equ MOSI_BIT      = PB3
.equ MISO_BIT      = PB4
.equ SCK_BIT       = PB5

.CSEG
.ORG 0x0000
    rjmp RESET

.ORG INT_VECTORS_SIZE
RESET:
    cli

    ldi  r16, HIGH(RAMEND)
    out  SPH, r16
    ldi  r16, LOW(RAMEND)
    out  SPL, r16

    ldi  r16, (1 << SS_BIT) | (1 << MOSI_BIT) | (1 << SCK_BIT)
    out  DDRB, r16

    ldi  r16, (1 << SS_BIT)
    out  PORTB, r16

    ldi  r16, (1 << SPE) | (1 << MSTR) | (1 << SPR0)
    out  SPCR, r16

    sei

MAIN_LOOP:
    cbi  PORTB, SS_BIT

    ldi  ZH, HIGH(MSG * 2)
    ldi  ZL, LOW(MSG * 2)
SEND_NEXT:
    lpm  r16, Z+
    tst  r16
    breq SEND_DONE
    rcall SPI_SEND_BYTE
    rjmp SEND_NEXT

SEND_DONE:
    sbi  PORTB, SS_BIT

    rcall DELAY_BIG
    rjmp MAIN_LOOP

SPI_SEND_BYTE:
    out  SPDR, r16
WAIT_SPIF:
    in   r17, SPSR
    sbrs r17, SPIF
    rjmp WAIT_SPIF
    in   r17, SPDR
    ret

DELAY_BIG:
    ldi  r18, 40
D1:
    ldi  r19, 255
D2:
    ldi  r20, 255
D3:
    dec  r20
    brne D3
    dec  r19
    brne D2
    dec  r18
    brne D1
    ret

MSG:
    .db "Hello, World!", 13, 10, 0

