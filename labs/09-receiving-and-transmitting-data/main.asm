.include "m168Adef.inc"

.equ F_CPU    = 16000000
.equ BAUD     = 9600
.equ UBRR_VAL = (F_CPU / (16 * BAUD)) - 1

.equ CMD_LEN   = 4
.equ DEV_ID    = '1'
.equ FUNC_RD   = 'R'
.equ FUNC_WR   = 'W'
.equ REG_COUNT = 16

.CSEG
.ORG 0x0
    rjmp RESET

.ORG URXCaddr
    rjmp RX_ISR

.ORG INT_VECTORS_SIZE

RESET:
    ldi r16, high(RAMEND)
    out SPH, r16
    ldi r16, low(RAMEND)
    out SPL, r16

    clr r2
    clr r3
    ldi XL, low(cmd_buf)
    ldi XH, high(cmd_buf)

    ldi YL, low(regs)
    ldi YH, high(regs)
    ldi r18, REG_COUNT
    clr r16
zero_regs:
    st Y+, r16
    dec r18
    brne zero_regs

    rcall UART_Init
    sei

wait_cmd:
    tst r3
    breq wait_cmd

    ldi XL, low(cmd_buf)
    ldi XH, high(cmd_buf)
    ld r20, X+
    ld r21, X+
    ld r22, X+
    ld r23, X+

    cpi r20, DEV_ID
    brne finish

    mov r16, r22
    rcall HEX2BIN
    brcs finish
    mov r22, r16

    cpi r22, REG_COUNT
    brsh finish

    ldi YL, low(regs)
    ldi YH, high(regs)
    clr r16
    add YL, r22
    adc YH, r16

    cpi r21, FUNC_WR
    breq write_reg
    cpi r21, FUNC_RD
    breq read_reg
    rjmp finish

write_reg:
    st Y, r23
    rjmp finish

read_reg:
    mov r16, r20
    rcall UART_Send

    mov r16, r22
    rcall BIN2HEX
    brcs finish
    rcall UART_Send

    ld r16, Y
    rcall UART_Send

    ldi r16, 0x0D
    rcall UART_Send

finish:
    clr r2
    clr r3
    ldi XL, low(cmd_buf)
    ldi XH, high(cmd_buf)

    lds r16, UCSR0B
    ori r16, (1<<RXCIE0)
    sts UCSR0B, r16

    rjmp wait_cmd

RX_ISR:
    push r16
    in r16, SREG
    push r16
    push r17

    lds r16, UDR0

    cpi r16, 0x0D
    breq isr_exit
    cpi r16, 0x0A
    breq isr_exit

    st X+, r16

    mov r16, r2
    inc r16
    mov r2, r16

    cpi r16, CMD_LEN
    brne isr_exit

    lds r17, UCSR0B
    andi r17, ~(1<<RXCIE0)
    sts UCSR0B, r17

    ser r16
    mov r3, r16

isr_exit:
    pop r17
    pop r16
    out SREG, r16
    pop r16
    reti

UART_Init:
    ldi r16, high(UBRR_VAL)
    sts UBRR0H, r16
    ldi r16, low(UBRR_VAL)
    sts UBRR0L, r16

    ldi r16, (1<<RXEN0) | (1<<TXEN0) | (1<<RXCIE0)
    sts UCSR0B, r16

    ldi r16, (1<<UCSZ01) | (1<<UCSZ00)
    sts UCSR0C, r16
    ret

UART_Send:
    push r17
tx_wait:
    lds r17, UCSR0A
    sbrs r17, UDRE0
    rjmp tx_wait
    sts UDR0, r16
    pop r17
    ret

HEX2BIN:
    cpi r16, '0'
    brlo hex2bin_err
    cpi r16, '9'+1
    brlo hex2bin_digit
    cpi r16, 'A'
    brlo hex2bin_err
    cpi r16, 'F'+1
    brsh hex2bin_err
    subi r16, 'A' - 10
    clc
    ret
hex2bin_digit:
    subi r16, '0'
    clc
    ret
hex2bin_err:
    sec
    ret

BIN2HEX:
    cpi r16, 16
    brsh bin2hex_err
    cpi r16, 10
    brlo bin2hex_digit
    ldi r17, 'A' - 10
    add r16, r17
    clc
    ret
bin2hex_digit:
    ldi r17, '0'
    add r16, r17
    clc
    ret
bin2hex_err:
    sec
    ret

.DSEG
.ORG SRAM_START
cmd_buf: .byte CMD_LEN
regs:    .byte REG_COUNT
