#include <stdint.h>

#define LED_REG      (*(volatile uint32_t *)0x10000000)
#define IMAGE_BASE   ((volatile uint32_t *)0x30000000)
#define HEX_REG      (*(volatile uint32_t *)0x40000000)

int main(void) {
    // 1. Read Word 0 from image RAM (0x3000_0000)
    uint32_t word0 = IMAGE_BASE[46];

    // 2. Extract Pixel 1 (bits [15:8]) by shifting right 8 bits
    uint8_t pixel1 = (uint8_t)((word0 >>0) & 0xFF);

    // 3. Display Pixel 1 on 7-Segment Display (HEX2-HEX0)
    HEX_REG = pixel1;

    // 4. Display on Green LEDs (LEDG[7:0])
    LED_REG = pixel1;

    while (1); // Hold display
}