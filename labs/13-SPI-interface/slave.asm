.include "m168Adef.inc"

.equ LO            = 0b00000000
.equ HI            = 0b11111111

.equ F_CPU    = 16000000
.equ BAUD     = 9600
.equ UBRR_VAL = (F_CPU / (16 * BAUD)) - 1

.equ SS_BIT        = PB2
.equ MOSI_BIT      = PB3
.equ MISO_BIT      = PB4
.equ SCK_BIT       = PB5

.equ RX_BUF_MASK   = 0x1F

.CSEG
.ORG 0x0000
    rjmp RESET
.ORG SPIaddr
    rjmp SPI_STC_ISR

.ORG INT_VECTORS_SIZE
RESET:
    cli

    ldi  r16, HIGH(RAMEND)
    out  SPH, r16
    ldi  r16, LOW(RAMEND)
    out  SPL, r16

    ldi  r16, HIGH(UBRR_VAL)
    sts  UBRR0H, r16
    ldi  r16, LOW(UBRR_VAL)
    sts  UBRR0L, r16

    ldi  r16, (1 << UCSZ01) | (1 << UCSZ00)
    sts  UCSR0C, r16

    ldi  r16, (1 << TXEN0)
    sts  UCSR0B, r16

    ldi  r16, (1 << MISO_BIT)
    out  DDRB, r16
    ldi  r16, LO
    out  PORTB, r16

    ldi  r16, (1 << SPE) | (1 << SPIE)
    out  SPCR, r16

    ldi  r16, 0
    sts  RX_HEAD, r16
    sts  RX_TAIL, r16

    ldi  ZH, HIGH(READY_MSG * 2)
    ldi  ZL, LOW(READY_MSG * 2)
    rcall UART_SEND_FLASH_STRING

    sei

MAIN_LOOP:
    lds  r17, RX_HEAD
    lds  r18, RX_TAIL
    cp   r17, r18
    breq MAIN_LOOP

    ldi  ZH, HIGH(RX_BUF)
    ldi  ZL, LOW(RX_BUF)
    add  ZL, r18
    clr  r19
    adc  ZH, r19
    ld   r16, Z

    inc  r18
    andi r18, RX_BUF_MASK
    sts  RX_TAIL, r18

    rcall UART_SEND_BYTE
    rjmp MAIN_LOOP

UART_SEND_BYTE:
UART_WAIT_UDRE:
    lds  r17, UCSR0A
    sbrs r17, UDRE0
    rjmp UART_WAIT_UDRE
    sts  UDR0, r16
    ret

UART_SEND_FLASH_STRING:
UART_STR_NEXT:
    lpm  r16, Z+
    tst  r16
    breq UART_STR_DONE
    rcall UART_SEND_BYTE
    rjmp UART_STR_NEXT
UART_STR_DONE:
    ret

SPI_STC_ISR:
    push r16
    in   r16, SREG
    push r16
    push r17
    push r18
    push r19
    push ZL
    push ZH

    in   r16, SPDR

    lds  r17, RX_HEAD
    lds  r18, RX_TAIL

    mov  r19, r17
    inc  r19
    andi r19, RX_BUF_MASK

    cp   r19, r18
    breq SPI_ISR_RESTORE

    ldi  ZH, HIGH(RX_BUF)
    ldi  ZL, LOW(RX_BUF)
    add  ZL, r17
    clr  r18
    adc  ZH, r18
    st   Z, r16

    sts  RX_HEAD, r19

SPI_ISR_RESTORE:
    pop  ZH
    pop  ZL
    pop  r19
    pop  r18
    pop  r17
    pop  r16
    out  SREG, r16
    pop  r16
    reti

READY_MSG:
    .db "Slave is ready!", 13, 10, 0

.DSEG
.ORG SRAM_START
RX_HEAD:
    .byte 1
RX_TAIL:
    .byte 1
RX_BUF:
    .byte 32

