.include "m168Adef.inc"

.equ UBRR_VAL  = 103
.equ EEP_ADDR  = 0x0000

.org 0x0000
    rjmp MAIN

MAIN:
    ldi r16, HIGH(RAMEND)
    out SPH, r16
    ldi r16, LOW(RAMEND)
    out SPL, r16

    rcall UART_Init

LOOP:
    rcall UART_ReceiveByte
    rcall EEPROM_Write
WAIT_WRITE:
    sbic EECR, EEPE
    rjmp WAIT_WRITE

    rcall EEPROM_Read
    inc r16
    rcall UART_SendByte
    rjmp LOOP

EEPROM_Write:
EEPROM_WRITE_WAIT:
    sbic EECR, EEPE
    rjmp EEPROM_WRITE_WAIT

    ldi r17, HIGH(EEP_ADDR)
    out EEARH, r17
    ldi r17, LOW(EEP_ADDR)
    out EEARL, r17

    out EEDR, r16

    sbi EECR, EEMPE

    sbi EECR, EEPE

    ret

EEPROM_Read:
EEPROM_READ_WAIT:
    sbic EECR, EEPE
    rjmp EEPROM_READ_WAIT

    ldi r17, HIGH(EEP_ADDR)
    out EEARH, r17
    ldi r17, LOW(EEP_ADDR)
    out EEARL, r17

    sbi EECR, EERE

    in r16, EEDR

    ret

UART_Init:
    ldi r16, HIGH(UBRR_VAL)
    sts UBRR0H, r16
    ldi r16, LOW(UBRR_VAL)
    sts UBRR0L, r16

    ldi r16, (1 << RXEN0) | (1 << TXEN0)
    sts UCSR0B, r16

    ldi r16, (1 << UCSZ01) | (1 << UCSZ00)
    sts UCSR0C, r16

    ret

UART_SendByte:
WAIT_TX:
    lds r17, UCSR0A
    sbrs r17, UDRE0
    rjmp WAIT_TX
    sts UDR0, r16
    ret

UART_ReceiveByte:
WAIT_RX:
    lds r17, UCSR0A
    sbrs r17, RXC0
    rjmp WAIT_RX
    lds r16, UDR0
    ret
