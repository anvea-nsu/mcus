.include "m168Adef.inc"

.equ LCD_E                  = PB0
.equ LCD_RW                 = PB1
.equ LCD_RS                 = PB2

.equ LCD_LINE1_ADDR         = 0x00
.equ LCD_LINE2_ADDR         = 0x40

.equ LCD_CMD_8BIT_2LINE_5X8 = 0x38
.equ LCD_CMD_CLEAR          = 0x01
.equ LCD_CMD_ENTRY_MODE     = 0x06

.equ LCD_CMD_DISPLAY_OFF    = 0b00001000
.equ LCD_CMD_DISPLAY_ON     = 0b00001100
.equ LCD_CMD_CURSOR_ON      = 0b00001010
.equ LCD_CMD_BLINK_CURSOR   = 0b00001001

.equ LCD_CMD_SET_CGRAM_ADDR = 0x40
.equ LCD_CMD_SET_DDRAM_ADDR = 0x80

.equ CUSTOM_CHAR_SLOT       = 1

.CSEG
.ORG 0x0000
    rjmp RESET

.ORG INT_VECTORS_SIZE
RESET:
    ldi r16, HIGH(RAMEND)
    out SPH, r16
    ldi r16, LOW(RAMEND)
    out SPL, r16

    cli

    ldi r16, (1 << PB0) | (1 << PB1) | (1 << PB2)
    out DDRB, r16

    ldi r16, 0xFF
    out DDRD, r16

    clr r16
    out PORTB, r16
    out PORTD, r16

    sei

    ldi r16, LCD_CMD_8BIT_2LINE_5X8
    rcall LCD_SendCommand

    ldi r16, LCD_CMD_DISPLAY_OFF
    rcall LCD_SendCommand

    ldi r16, LCD_CMD_CLEAR
    rcall LCD_SendCommand

    ldi r16, LCD_CMD_ENTRY_MODE
    rcall LCD_SendCommand

    ldi r16, LCD_CMD_DISPLAY_ON | LCD_CMD_CURSOR_ON | LCD_CMD_BLINK_CURSOR
    rcall LCD_SendCommand

    rcall LCD_LoadCustomChar

    ldi r16, LCD_CMD_SET_DDRAM_ADDR | LCD_LINE1_ADDR
    rcall LCD_SendCommand
    ldi ZH, HIGH(Message1 << 1)
    ldi ZL, LOW(Message1 << 1)
    rcall LCD_PrintFromFlash

    ldi r16, LCD_CMD_SET_DDRAM_ADDR | LCD_LINE2_ADDR
    rcall LCD_SendCommand
    ldi ZH, HIGH(Message2 << 1)
    ldi ZL, LOW(Message2 << 1)
    rcall LCD_PrintFromFlash

MAIN_LOOP:
    rjmp MAIN_LOOP

LCD_SendCommand:
    cbi PORTB, LCD_RS
    cbi PORTB, LCD_RW
    rcall LCD_WriteByte
    rcall LongDelay
    ret

LCD_SendData:
    sbi PORTB, LCD_RS
    cbi PORTB, LCD_RW
    rcall LCD_WriteByte
    rcall LongDelay
    ret

LongDelay:
    ldi r24, 20
DL1:
    ldi r25, 255
DL2:
    dec r25
    brne DL2
    dec r24
    brne DL1
    ret

LCD_WriteByte:
    ldi r17, 0xFF
    out DDRD, r17
    out PORTD, r16
    sbi PORTB, LCD_E
    cbi PORTB, LCD_E
    ret

LCD_PrintFromFlash:
    lpm r16, Z+
    tst r16
    breq PrintDone
    rcall LCD_SendData
    rjmp LCD_PrintFromFlash
PrintDone:
    ret

LCD_LoadCustomChar:
    ldi r16, LCD_CMD_SET_CGRAM_ADDR | (CUSTOM_CHAR_SLOT * 8)
    rcall LCD_SendCommand
    ldi ZH, HIGH(CustomCharData << 1)
    ldi ZL, LOW(CustomCharData << 1)
    ldi r18, 8
LoadLoop:
    lpm r16, Z+
    rcall LCD_SendData
    dec r18
    brne LoadLoop
    ldi r16, LCD_CMD_SET_DDRAM_ADDR
    rcall LCD_SendCommand
    ret

CustomCharData:
    .db 0b00000, 0b00000, 0b11011, 0b11011, 0b00100, 0b01110, 0b01010, 0b00000

Message1:
    .db "Hello, World!", 0

Message2:
    .db "I SEE YOU! ", CUSTOM_CHAR_SLOT, 0
