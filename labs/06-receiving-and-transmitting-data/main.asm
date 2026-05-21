.include "m168Adef.inc"

.equ UBRR_VAL = 103

.org 0x0000
    rjmp    MAIN

MAIN:
    ldi     r16, HIGH(RAMEND)
    out     SPH, r16
    ldi     r16, LOW(RAMEND)
    out     SPL, r16

    rcall   UART_Init

    rcall   UART_SendHello

LOOP:
    rcall   UART_ReceiveByte
    rcall   UART_SendByte
    rjmp    LOOP

UART_Init:
    ldi     r16, HIGH(UBRR_VAL)
    sts     UBRR0H, r16
    ldi     r16, LOW(UBRR_VAL)
    sts     UBRR0L, r16

    ldi     r16, (1 << RXEN0) | (1 << TXEN0)
    sts     UCSR0B, r16

    ldi     r16, (1 << UCSZ01) | (1 << UCSZ00)
    sts     UCSR0C, r16

    ret

UART_SendByte:
WAIT_TX:
    lds     r17, UCSR0A
    sbrs    r17, UDRE0
    rjmp    WAIT_TX

    sts     UDR0, r16

    ret

UART_ReceiveByte:
WAIT_RX:
    lds     r17, UCSR0A
    sbrs    r17, RXC0
    rjmp    WAIT_RX

    lds     r16, UDR0

    ret

UART_SendHello:
    ldi     r16, 'H'
    rcall   UART_SendByte
    ldi     r16, 'e'
    rcall   UART_SendByte
    ldi     r16, 'l'
    rcall   UART_SendByte
    ldi     r16, 'l'
    rcall   UART_SendByte
    ldi     r16, 'o'
    rcall   UART_SendByte
    ldi     r16, '!'
    rcall   UART_SendByte
    ldi     r16, 0x0D
    rcall   UART_SendByte
    ldi     r16, 0x0A
    rcall   UART_SendByte

    ret
