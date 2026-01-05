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
    mmio_write(0x0000, 0xDEADBEEF);
    mmio_write(0x0004, 0xCAFEBABE);
    mmio_write(0x0008, 0x12345678);
    mmio_write(0x000C, 0xABCDEF00);
    printf("\n");

    // Test 2: Read data from VCS
    printf("--- Test 2: Reading data from VCS ---\n");
    uint32_t val1 = mmio_read(0x0000);
    uint32_t val2 = mmio_read(0x0004);
    uint32_t val3 = mmio_read(0x0008);
    uint32_t val4 = mmio_read(0x000C);
    printf("\n");

    // Test 3: Verify read values
    printf("--- Test 3: Verification ---\n");
    printf("Read value 1: 0x%08x %s\n", val1, (val1 == 0xDEADBEEF) ? "✓" : "✗");
    printf("Read value 2: 0x%08x %s\n", val2, (val2 == 0xCAFEBABE) ? "✓" : "✗");
    printf("Read value 3: 0x%08x %s\n", val3, (val3 == 0x12345678) ? "✓" : "✗");
    printf("Read value 4: 0x%08x %s\n", val4, (val4 == 0xABCDEF00) ? "✓" : "✗");
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
