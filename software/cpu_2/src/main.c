#include <stdint.h>

#define CPU_HZ      50000000u
#define IMG         ((volatile uint8_t *)0x30000000)
#define IMG_BYTES   4096

#define JT_DATA     (*(volatile uint32_t *)0x50000000)
#define JT_CTRL     (*(volatile uint32_t *)0x50000004)
#define LCD         (*(volatile uint32_t *)0x60000000)

static inline uint32_t cycles(void) {
    uint32_t c; __asm__ volatile ("rdcycle %0" : "=r"(c)); return c;
}
static void delay_us(uint32_t us) {
    uint32_t t = cycles(), n = us * (CPU_HZ / 1000000u);
    while (cycles() - t < n);
}
static void delay_ms(uint32_t ms) { while (ms--) delay_us(1000); }

/* ---- JTAG UART ---- */
static void uart_putc(uint8_t c) {
    while ((JT_CTRL >> 16) == 0);          // wait for write space
    JT_DATA = c;
}
static uint8_t uart_getc(void) {
    uint32_t v;
    do { v = JT_DATA; } while (!(v & 0x8000));   // RVALID
    return (uint8_t)(v & 0xFF);
}
static void put_hex(uint8_t v) {
    static const char H[] = "0123456789ABCDEF";
    uart_putc(H[v >> 4]);
    uart_putc(H[v & 15]);
}

/* ---- LCD (HD44780, 8-bit) ---- */
static void lcd_write(uint8_t rs, uint8_t v, uint32_t wait_us) {
    uint32_t base = ((uint32_t)rs << 8) | v;
    LCD = base;               // RS/data first, EN low
    delay_us(1);
    LCD = base | (1u << 9);   // EN high
    delay_us(2);
    LCD = base;               // EN low, data latched
    delay_us(wait_us);
}
static void lcd_cmd(uint8_t c)  { lcd_write(0, c, (c <= 0x02) ? 2000 : 60); }
static void lcd_putc(char c)    { lcd_write(1, (uint8_t)c, 60); }
static void lcd_print(const char *s) { while (*s) lcd_putc(*s++); }
static void lcd_line(int n)     { lcd_cmd(n ? 0xC0 : 0x80); }
static void lcd_init(void) {
    delay_ms(30);
    lcd_cmd(0x38); delay_ms(5);
    lcd_cmd(0x38); delay_us(150);
    lcd_cmd(0x38);
    lcd_cmd(0x0C);
    lcd_cmd(0x01);
    lcd_cmd(0x06);
}

int main(void) {
    lcd_init();
    lcd_line(0); lcd_print("Sending image...");

    uint8_t sum = 0;
    for (int r = 0; r < 64; r++) {          // 64 text lines of 128 hex chars
        for (int c = 0; c < 64; c++) {
            uint8_t p = IMG[r * 64 + c];
            sum += p;
            put_hex(p);
        }
        uart_putc('\n');
    }
    uart_putc('S'); put_hex(sum); uart_putc('\n');
    for (int i = 0; i < 4096; i++) uart_putc('\n');   // flush padding

    lcd_cmd(0x01);
    lcd_line(0); lcd_print("Waiting for PC..");

    uint8_t ack = uart_getc();
    lcd_cmd(0x01);
    if (ack == 'K') {
        lcd_line(0); lcd_print("Completed");
        lcd_line(1); lcd_print("and Saved");
    } else {
        lcd_line(0); lcd_print("Transfer error");
    }
    while (1);
}