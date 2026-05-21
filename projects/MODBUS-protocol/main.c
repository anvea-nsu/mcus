#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdint.h>
#include <string.h>

#define F_CPU           16000000UL
#define BAUD            9600UL
#define UBRR_VALUE      ((F_CPU / (16UL * BAUD)) - 1)   /* = 103 */

#define SLAVE_ID        0x01
#define NUM_COILS       8

#define LAMP_DDR        DDRB
#define LAMP_PORT       PORTB

#define FC_READ_COILS           0x01
#define FC_WRITE_SINGLE_COIL    0x05
#define FC_WRITE_MULTI_COILS    0x0F

#define EX_ILLEGAL_FUNCTION     0x01
#define EX_ILLEGAL_DATA_ADDR    0x02

#define RX_BUF_SIZE     64
#define TX_BUF_SIZE     32

#define MODBUS_TIMEOUT_TICKS    999u

static volatile uint8_t rx_buf[RX_BUF_SIZE];
static volatile uint8_t rx_len      = 0;
static volatile uint8_t frame_ready = 0;

static uint8_t  tx_buf[TX_BUF_SIZE];

static uint8_t  coil_state = 0x00;



static uint16_t crc16_modbus(const uint8_t *data, uint8_t len)
{
    uint16_t crc = 0xFFFFu;
    for (uint8_t i = 0; i < len; i++) {
        crc ^= (uint16_t)data[i];
        for (uint8_t b = 0; b < 8; b++) {
            if (crc & 0x0001u) {
                crc = (crc >> 1) ^ 0xA001u;
            } else {
                crc >>= 1;
            }
        }
    }
    return crc;
}

static void uart_init(void)
{
    UBRR0H = (uint8_t)(UBRR_VALUE >> 8);
    UBRR0L = (uint8_t)(UBRR_VALUE & 0xFF);

    UCSR0B = (1 << RXEN0) | (1 << TXEN0) | (1 << RXCIE0);
    UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);
}

static void uart_send_byte(uint8_t byte)
{
    while (!(UCSR0A & (1 << UDRE0)));
    UDR0 = byte;
}

static void uart_send_buf(const uint8_t *buf, uint8_t len)
{
    for (uint8_t i = 0; i < len; i++) {
        uart_send_byte(buf[i]);
    }
}

static void timer1_init(void)
{
    TCCR1A = 0;
    TCCR1B = (1 << WGM12);
    OCR1A  = MODBUS_TIMEOUT_TICKS;
    TIMSK1 = (1 << OCIE1A);
}

static inline void timer1_restart(void)
{
    TCNT1  = 0;
    TCCR1B = (1 << WGM12) | (1 << CS11) | (1 << CS10);
}

static inline void timer1_stop(void)
{
    TCCR1B = (1 << WGM12);
    TCNT1  = 0;
}

ISR(USART_RX_vect)
{
    uint8_t byte = UDR0;
    if (!frame_ready && rx_len < RX_BUF_SIZE) {
        rx_buf[rx_len++] = byte;
        timer1_restart();
    }
}

ISR(TIMER1_COMPA_vect)
{
    timer1_stop();
    if (rx_len > 0) {
        frame_ready = 1;
    }
}

static void send_exception(uint8_t func_code, uint8_t ex_code)
{
    tx_buf[0] = SLAVE_ID;
    tx_buf[1] = func_code | 0x80u;
    tx_buf[2] = ex_code;
    uint16_t crc = crc16_modbus(tx_buf, 3);
    tx_buf[3]    = (uint8_t)(crc & 0xFFu);
    tx_buf[4]    = (uint8_t)(crc >> 8);
    uart_send_buf(tx_buf, 5);
}

static void process_modbus_frame(void)
{
    if (rx_len < 4) return;

    if (rx_buf[0] != SLAVE_ID) return;

    uint16_t recv_crc = (uint16_t)rx_buf[rx_len - 2]
                      | ((uint16_t)rx_buf[rx_len - 1] << 8);
    uint16_t calc_crc = crc16_modbus((const uint8_t *)rx_buf, rx_len - 2);
    if (recv_crc != calc_crc) return;

    uint8_t func = rx_buf[1];

    if (func == FC_READ_COILS) {

        if (rx_len != 8) return;

        uint16_t start = ((uint16_t)rx_buf[2] << 8) | rx_buf[3];
        uint16_t qty   = ((uint16_t)rx_buf[4] << 8) | rx_buf[5];

        if (qty == 0 || start >= NUM_COILS || (start + qty) > NUM_COILS) {
            send_exception(func, EX_ILLEGAL_DATA_ADDR);
            return;
        }

        uint8_t byte_cnt = (uint8_t)((qty + 7u) / 8u);
        tx_buf[0] = SLAVE_ID;
        tx_buf[1] = FC_READ_COILS;
        tx_buf[2] = byte_cnt;

        for (uint8_t b = 0; b < byte_cnt; b++) tx_buf[3 + b] = 0x00;

        for (uint8_t i = 0; i < qty; i++) {
            if (coil_state & (1u << (start + i))) {
                tx_buf[3 + i / 8] |= (uint8_t)(1u << (i % 8));
            }
        }

        uint8_t  resp_len = 3u + byte_cnt;
        uint16_t crc      = crc16_modbus(tx_buf, resp_len);
        tx_buf[resp_len]     = (uint8_t)(crc & 0xFFu);
        tx_buf[resp_len + 1] = (uint8_t)(crc >> 8);
        uart_send_buf(tx_buf, resp_len + 2u);
    }
    else if (func == FC_WRITE_SINGLE_COIL) {

        if (rx_len != 8) return;

        uint16_t addr  = ((uint16_t)rx_buf[2] << 8) | rx_buf[3];
        uint16_t value = ((uint16_t)rx_buf[4] << 8) | rx_buf[5];

        if (addr >= NUM_COILS) {
            send_exception(func, EX_ILLEGAL_DATA_ADDR);
            return;
        }
        if (value != 0xFF00u && value != 0x0000u) {
            send_exception(func, EX_ILLEGAL_DATA_ADDR);
            return;
        }

        if (value == 0xFF00u) {
            coil_state |=  (uint8_t)(1u << addr);
        } else {
            coil_state &= (uint8_t)~(1u << addr);
        }
        LAMP_PORT = coil_state;

        uart_send_buf((const uint8_t *)rx_buf, rx_len);
    }
    else if (func == FC_WRITE_MULTI_COILS) {
        if (rx_len < 9) return;

        uint16_t start    = ((uint16_t)rx_buf[2] << 8) | rx_buf[3];
        uint16_t qty      = ((uint16_t)rx_buf[4] << 8) | rx_buf[5];
        uint8_t  byte_cnt = rx_buf[6];

        uint8_t expected_len = (uint8_t)(9u + byte_cnt);
        if (rx_len != expected_len) return;

        if (qty == 0 || start >= NUM_COILS || (start + qty) > NUM_COILS) {
            send_exception(func, EX_ILLEGAL_DATA_ADDR);
            return;
        }

        for (uint8_t i = 0; i < qty; i++) {
            uint8_t bit = (rx_buf[7u + i / 8u] >> (i % 8u)) & 0x01u;
            if (bit) {
                coil_state |=  (uint8_t)(1u << (start + i));
            } else {
                coil_state &= (uint8_t)~(1u << (start + i));
            }
        }
        LAMP_PORT = coil_state;

        tx_buf[0] = SLAVE_ID;
        tx_buf[1] = FC_WRITE_MULTI_COILS;
        tx_buf[2] = rx_buf[2];
        tx_buf[3] = rx_buf[3];
        tx_buf[4] = rx_buf[4];
        tx_buf[5] = rx_buf[5];
        uint16_t crc = crc16_modbus(tx_buf, 6);
        tx_buf[6]    = (uint8_t)(crc & 0xFFu);
        tx_buf[7]    = (uint8_t)(crc >> 8);
        uart_send_buf(tx_buf, 8);
    }
    else {
        send_exception(func, EX_ILLEGAL_FUNCTION);
    }
}

int main(void)
{
    LAMP_DDR  = 0xFF;
    LAMP_PORT = 0x00;

    uart_init();
    timer1_init();
    sei();

    while (1) {
        if (frame_ready) {
            process_modbus_frame();

            cli();
            rx_len      = 0;
            frame_ready = 0;
            sei();
        }
    }

    return 0;
}
