#include <stdint.h>

#define IMG_BASE  0x30000000u
#define LED_REG   (*(volatile uint32_t *)0x10000000u)
#define HEX_REG   (*(volatile uint32_t *)0x40000000u)
    
#define NUM_PIXELS (256 * 256)

#define CLK_HZ    50000000u   // set to your PLL c0 frequency
#define DELAY_MS  200u        // time per pixel

static volatile uint8_t *const img = (volatile uint8_t *)IMG_BASE;

static inline uint32_t rdcycle(void)
{
    uint32_t c;
    __asm__ volatile ("rdcycle %0" : "=r"(c));
    return c;
}

static void delay_ms(uint32_t ms)
{
    uint32_t ticks = (CLK_HZ / 1000u) * ms;
    uint32_t start = rdcycle();
    while ((uint32_t)(rdcycle() - start) < ticks) { }
}

int main(void)
{
    while (1) {
        for (uint32_t i = 0; i < NUM_PIXELS; i++) {
            uint8_t p = img[i];
            HEX_REG = p;    // decimal on HEX2..HEX0
            LED_REG = p;    // binary on LEDG[7:0]
            delay_ms(DELAY_MS);
        }
    }
}