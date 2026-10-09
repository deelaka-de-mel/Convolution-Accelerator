#include <stdint.h>

// Peripheral Base Addresses
#define LED_REG      (*(volatile uint32_t *)0x10000000)
#define CONV_BASE    0x20000000
#define IMAGE_BASE   ((volatile uint32_t *)0x30000000)
#define HEX_REG      (*(volatile uint32_t *)0x40000000)

// Accelerator Control Registers (CSRs at 0x2000_0000)
#define REG_CTRL     *(volatile uint32_t *)(CONV_BASE + 0x00)
#define REG_STATUS   *(volatile uint32_t *)(CONV_BASE + 0x04)
#define REG_IMG_ADDR *(volatile uint32_t *)(CONV_BASE + 0x08)
#define REG_SIZE     *(volatile uint32_t *)(CONV_BASE + 0x0C)

int main(void) {
    // 1. Read Word 0 from Dual-Port Image RAM
    uint32_t packed_pixels = IMAGE_BASE[0];

    // 2. Extract Pixel 0 (Bits [7:0]) -> 0xB2 (178 decimal)
    uint8_t pixel0 = (uint8_t)(packed_pixels & 0xFF);

    // 3. Display 178 on HEX2-HEX0
    HEX_REG = pixel0;

    // 4. Display 0xB2 on Green LEDs
    LED_REG = pixel0;

    // 5. Configure Fake Accelerator
    REG_IMG_ADDR = 0x30000000;
    REG_SIZE     = (512 << 16) | 512;

    // 6. Trigger Computation
    REG_CTRL = 0x01;

    // 7. Poll STATUS until DONE bit is set
    while ((REG_STATUS & 0x02) == 0);

    // 8. Hold output
    while (1);
}