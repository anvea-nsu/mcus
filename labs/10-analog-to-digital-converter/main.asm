.include "m168Adef.inc"

.CSEG
.ORG 0x0
    rjmp RESET

.ORG INT_VECTORS_SIZE
RESET:
    ldi  r16, HIGH(RAMEND)
    out  SPH, r16
    ldi  r16, LOW(RAMEND)
    out  SPL, r16

    ldi  r16, 0xFF
    out  DDRD, r16
    ldi  r16, 0x00
    out  PORTD, r16

    ldi  r16, 0x03
    out  DDRB, r16
    ldi  r16, 0x00
    out  PORTB, r16

    ldi  r16, (1 << REFS0)
    sts  ADMUX, r16
    ldi  r16, (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0)
    sts  ADCSRA, r16
MAIN_LOOP:
    lds  r16, ADCSRA
    ori  r16, (1 << ADSC)
    sts  ADCSRA, r16
ADC_WAIT:
    lds  r16, ADCSRA
    sbrc r16, ADSC
    rjmp ADC_WAIT

    lds  r17, ADCL
    lds  r18, ADCH

    out  PORTD, r17
    out  PORTB, r18

    rjmp MAIN_LOOP

.DSEG
.ORG SRAM_START
