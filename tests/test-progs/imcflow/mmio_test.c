// Test program that performs MMIO read/write to ImcflowPIO device
// Compile: gcc -static -o mmio_test mmio_test.c

#include <stdint.h>
#include <stdio.h>

// ImcflowPIO device base address
#define IMC_BASE 0x80000000UL

// Helper functions for MMIO access
static inline void mmio_write32(uintptr_t addr, uint32_t value) {
    *(volatile uint32_t*)addr = value;
}

static inline uint32_t mmio_read32(uintptr_t addr) {
    return *(volatile uint32_t*)addr;
}

int main() {
    printf("ImcflowPIO MMIO Test\n");
    printf("====================\n\n");

    // Test 1: Write to address 0x0
    printf("[Test 1] Writing 0xDEADBEEF to offset 0x0\n");
    mmio_write32(IMC_BASE + 0x0, 0xDEADBEEF);
    printf("         Write complete\n\n");

    // Test 2: Write to address 0x4
    printf("[Test 2] Writing 0x12345678 to offset 0x4\n");
    mmio_write32(IMC_BASE + 0x4, 0x12345678);
    printf("         Write complete\n\n");

    // Test 3: Read from address 0x0
    printf("[Test 3] Reading from offset 0x0\n");
    uint32_t value1 = mmio_read32(IMC_BASE + 0x0);
    printf("         Read value: 0x%08X\n\n", value1);

    // Test 4: Read from address 0x4
    printf("[Test 4] Reading from offset 0x4\n");
    uint32_t value2 = mmio_read32(IMC_BASE + 0x4);
    printf("         Read value: 0x%08X\n\n", value2);

    // Test 5: Multiple writes
    printf("[Test 5] Multiple sequential writes\n");
    for (int i = 0; i < 5; i++) {
        uint32_t addr = 0x100 + (i * 4);
        uint32_t data = 0xA0A0 + i;
        printf("         Writing 0x%08X to offset 0x%03X\n", data, addr);
        mmio_write32(IMC_BASE + addr, data);
    }
    printf("         All writes complete\n\n");

    printf("====================\n");
    printf("All tests completed!\n");

    return 0;
}
