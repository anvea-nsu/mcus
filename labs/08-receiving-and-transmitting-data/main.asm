.include "m168Adef.inc"

.equ UBRR_VAL   = 103
.equ BUF_SIZE   = 10
.equ EOL        = 0x00

.equ rx_buf     = 0x0100
.equ tx_buf     = 0x010A

; r16 — временный регистр (общий)
; r17 — временный регистр (в ISR)
; r18 — счётчик принятых байт (rx_count)
; r19 — счётчик переданных байт (tx_count)
; r20 — флаги: бит 0 = строка принята (rx_done), бит 1 = передача идёт

.org 0x0000
    rjmp    RESET

.org 0x0002
    reti

.org 0x0004
    reti

.org 0x0006
    reti

.org 0x0008
    reti

.org 0x000A
    reti

.org 0x000C
    reti

.org 0x000E
    reti

.org 0x0010
    reti

.org 0x0012
    reti

.org 0x0014
    reti

.org 0x0016
    reti

.org 0x0018
    reti

.org 0x001A
    reti

.org 0x001C
    reti

.org 0x001E
    reti

.org 0x0020
    reti

.org 0x0022
    reti

.org 0x0024
    rjmp    ISR_USART_RX

.org 0x0026
    rjmp    ISR_USART_UDRE

.org 0x0028
    reti


.org 0x002A
RESET:
    ldi     r16, HIGH(RAMEND)
    out     SPH, r16
    ldi     r16, LOW(RAMEND)
    out     SPL, r16

    clr     r18
    clr     r19
    clr     r20

    rcall   UART_Init

    sei

MAIN_LOOP:
    sbrs    r20, 0
    rjmp    MAIN_LOOP

    cbr     r20, (1 << 0)

    rcall   CopyRxToTx

    clr     r19
    lds     r16, UCSR0B
    ori     r16, (1 << UDRIE0)
    sts     UCSR0B, r16

WAIT_TX_DONE:
    sbrc    r20, 1
    rjmp    WAIT_TX_DONE

    clr     r18

    rjmp    MAIN_LOOP

UART_Init:
    ldi     r16, HIGH(UBRR_VAL)
    sts     UBRR0H, r16
    ldi     r16, LOW(UBRR_VAL)
    sts     UBRR0L, r16

    ldi     r16, (1 << RXCIE0) | (1 << RXEN0) | (1 << TXEN0)
    sts     UCSR0B, r16

    ldi     r16, (1 << UCSZ01) | (1 << UCSZ00)
    sts     UCSR0C, r16

    ret

CopyRxToTx:
    ldi     r30, LOW(rx_buf)
    ldi     r31, HIGH(rx_buf)
    ldi     r26, LOW(tx_buf)
    ldi     r27, HIGH(tx_buf)

    ldi     r16, BUF_SIZE
COPY_LOOP:
    ld      r17, Z+
    st      X+, r17
    dec     r16
    brne    COPY_LOOP

    ret

ISR_USART_RX:
    push    r16
    push    r17
    in      r17, SREG
    push    r17

    lds     r16, UDR0

    ldi     r30, LOW(rx_buf)
    ldi     r31, HIGH(rx_buf)
    add     r30, r18
    brcc    NO_CARRY_RX
    inc     r31
NO_CARRY_RX:
    st      Z, r16

    inc     r18

    cpi     r16, EOL
    breq    RX_DONE
    cpi     r18, BUF_SIZE
    brsh    RX_DONE

    rjmp    RX_EXIT

RX_DONE:
    ldi     r30, LOW(rx_buf + BUF_SIZE - 1)
    ldi     r31, HIGH(rx_buf + BUF_SIZE - 1)
    ldi     r16, EOL
    st      Z, r16

    sbr     r20, (1 << 0) | (1 << 1)

RX_EXIT:
    pop     r17
    out     SREG, r17
    pop     r17
    pop     r16
    reti

ISR_USART_UDRE:
    push    r16
    push    r17
    in      r17, SREG
    push    r17

    cpi     r19, BUF_SIZE
    brsh    TX_DONE

    ldi     r30, LOW(tx_buf)
    ldi     r31, HIGH(tx_buf)
    add     r30, r19
    brcc    NO_CARRY_TX
    inc     r31
NO_CARRY_TX:
    ld      r16, Z

    sts     UDR0, r16

    inc     r19

    rjmp    TX_EXIT

TX_DONE:
    lds     r16, UCSR0B
    cbr     r16, (1 << UDRIE0)
    sts     UCSR0B, r16

    cbr     r20, (1 << 1)

TX_EXIT:
    pop     r17
    out     SREG, r17
    pop     r17
    pop     r16
    reti
