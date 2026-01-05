#include <stdint.h>
#include <stdio.h>

// MMIO base address (must match gem5 config)
#define IMC_BASE 0x80000000

// Helper functions for MMIO access
static inline void mmio_write(uint32_t offset, uint32_t value) {
    volatile uint32_t *addr = (volatile uint32_t*)(IMC_BASE + offset);
    printf("[gem5 → VCS] WRITE: offset=0x%04x, value=0x%08x\n", offset, value);
    *addr = value;
}

static inline uint32_t mmio_read(uint32_t offset) {
    volatile uint32_t *addr = (volatile uint32_t*)(IMC_BASE + offset);
    uint32_t value = *addr;
    printf("[VCS → gem5] READ:  offset=0x%04x, value=0x%08x\n", offset, value);
    return value;
}

int main() {
    printf("\n");
    printf("========================================\n");
    printf("  gem5 ↔ VCS Communication Test\n");
    printf("========================================\n");
    printf("MMIO Base Address: 0x%08x\n", IMC_BASE);
    printf("\n");

    // Test 1: Write some data to VCS
    printf("--- Test 1: Writing data to VCS ---\n");
    mmio_write(0x0500, 0xDEADBEEF);
    mmio_write(0x0504, 0xCAFEBABE);
    mmio_write(0x0508, 0x12345678);
    mmio_write(0x050C, 0xABCDEF00);
    mmio_write(0x0510, 0x0BADF00D);
    mmio_write(0x0514, 0xFEEDC0DE);
    mmio_write(0x0518, 0xB16B00B5);
    mmio_write(0x051C, 0xDEADC0DE);
    printf("\n");

    // Test 2: Read data from VCS
    printf("--- Test 2: Reading data from VCS ---\n");
    uint32_t val1 = mmio_read(0x0500);
    uint32_t val2 = mmio_read(0x0504);
    uint32_t val3 = mmio_read(0x0508);
    uint32_t val4 = mmio_read(0x050C);
    uint32_t val5 = mmio_read(0x0510);
    uint32_t val6 = mmio_read(0x0514);
    uint32_t val7 = mmio_read(0x0518);
    uint32_t val8 = mmio_read(0x051C);
    printf("\n");

    // Test 3: Verify read values
    printf("--- Test 3: Verification ---\n");
    printf("Read value 1: 0x%08x %s\n", val1, (val1 == 0xDEADBEEF) ? "✓" : "✗");
    printf("Read value 2: 0x%08x %s\n", val2, (val2 == 0xCAFEBABE) ? "✓" : "✗");
    printf("Read value 3: 0x%08x %s\n", val3, (val3 == 0x12345678) ? "✓" : "✗");
    printf("Read value 4: 0x%08x %s\n", val4, (val4 == 0xABCDEF00) ? "✓" : "✗");
    printf("Read value 5: 0x%08x %s\n", val5, (val5 == 0x0BADF00D) ? "✓" : "✗");
    printf("Read value 6: 0x%08x %s\n", val6, (val6 == 0xFEEDC0DE) ? "✓" : "✗");
    printf("Read value 7: 0x%08x %s\n", val7, (val7 == 0xB16B00B5) ? "✓" : "✗");
    printf("Read value 8: 0x%08x %s\n", val8, (val8 == 0xDEADC0DE) ? "✓" : "✗");
    printf("\n");

    // Test 4: Mixed read/write pattern
    printf("--- Test 4: Mixed operations ---\n");
    mmio_write(0x0100, 0x11111111);
    uint32_t r1 = mmio_read(0x0100);
    mmio_write(0x0104, 0x22222222);
    uint32_t r2 = mmio_read(0x0104);
    printf("Echo test: wrote 0x11111111, read 0x%08x %s\n", r1, (r1 == 0x11111111) ? "✓" : "✗");
    printf("Echo test: wrote 0x22222222, read 0x%08x %s\n", r2, (r2 == 0x22222222) ? "✓" : "✗");
    printf("\n");

    printf("========================================\n");
    printf("  Communication Test Complete!\n");
    printf("========================================\n");
    printf("\n");

    return 0;
}
