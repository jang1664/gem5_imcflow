#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdlib.h>

// ImcFlow device base address (should match gem5 config)
#define IMCFLOW_BASE    0x80000000UL
#define IMCFLOW_SIZE    0x20000UL

// Register offsets (based on params.py)
#define REG_STATE       0x00    // REG_STATE_ID = 0
#define REG_CMD         0x04    // REG_CMD_ID_BASE = 1
#define REG_INODE_PC0   0x08    // REG_INODE_PC_ID_BASE = 2
#define REG_INODE_PC1   0x0C
#define REG_INODE_PC2   0x10
#define REG_INODE_PC3   0x14

// Memory regions (based on address map)
#define INODE0_INST_BASE  0x80      // inode0 instruction memory
#define INODE0_DATA_BASE  0x480     // inode0 data memory (0x80 + 0x400)
#define INODE1_INST_BASE  0x10080   // inode1 instruction memory
#define INODE1_DATA_BASE  0x10480   // inode1 data memory

// State values
#define STATE_IDLE      0
#define STATE_RUN       1
#define STATE_PROGRAM   2

// Test patterns
#define TEST_PATTERN1   0xDEADBEEF
#define TEST_PATTERN2   0xCAFEBABE
#define TEST_PATTERN3   0x12345678

volatile uint32_t *imcflow_regs;
volatile uint32_t *imcflow_mem;

int map_imcflow_device() {
    printf("Mapping ImcFlow device at 0x%lx (size: 0x%lx)\n", IMCFLOW_BASE, IMCFLOW_SIZE);

    // In real hardware, we'd open /dev/mem
    // For gem5 simulation, we use direct memory access
    imcflow_regs = (volatile uint32_t*)IMCFLOW_BASE;
    imcflow_mem = (volatile uint32_t*)IMCFLOW_BASE;

    return 0;
}

void test_register_access() {
    printf("\n=== Testing Register Access ===\n");

    // Read initial state
    uint32_t state = imcflow_regs[REG_STATE/4];
    printf("Initial state: %u (expected: %u)\n", state, STATE_IDLE);

    // Read initial command register
    uint32_t cmd = imcflow_regs[REG_CMD/4];
    printf("Initial command: %u\n", cmd);

    // Test PC register writes
    printf("Testing PC register writes...\n");
    imcflow_regs[REG_INODE_PC0/4] = TEST_PATTERN1;
    imcflow_regs[REG_INODE_PC1/4] = TEST_PATTERN2;

    uint32_t pc0 = imcflow_regs[REG_INODE_PC0/4];
    uint32_t pc1 = imcflow_regs[REG_INODE_PC1/4];

    printf("PC0: wrote 0x%08x, read 0x%08x %s\n",
           TEST_PATTERN1, pc0, (pc0 == TEST_PATTERN1) ? "✓" : "✗");
    printf("PC1: wrote 0x%08x, read 0x%08x %s\n",
           TEST_PATTERN2, pc1, (pc1 == TEST_PATTERN2) ? "✓" : "✗");
}

void test_instruction_memory() {
    printf("\n=== Testing Instruction Memory ===\n");

    // Test inode0 instruction memory
    volatile uint32_t *inst_mem = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE0_INST_BASE);

    printf("Writing to inode0 instruction memory...\n");
    inst_mem[0] = TEST_PATTERN1;
    inst_mem[1] = TEST_PATTERN2;
    inst_mem[2] = TEST_PATTERN3;

    uint32_t inst0 = inst_mem[0];
    uint32_t inst1 = inst_mem[1];
    uint32_t inst2 = inst_mem[2];

    printf("Inst[0]: wrote 0x%08x, read 0x%08x %s\n",
           TEST_PATTERN1, inst0, (inst0 == TEST_PATTERN1) ? "✓" : "✗");
    printf("Inst[1]: wrote 0x%08x, read 0x%08x %s\n",
           TEST_PATTERN2, inst1, (inst1 == TEST_PATTERN2) ? "✓" : "✗");
    printf("Inst[2]: wrote 0x%08x, read 0x%08x %s\n",
           TEST_PATTERN3, inst2, (inst2 == TEST_PATTERN3) ? "✓" : "✗");
}

void test_data_memory() {
    printf("\n=== Testing Data Memory ===\n");

    // Test inode0 data memory (256-bit wide, but we'll access as 32-bit words)
    volatile uint32_t *data_mem = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE0_DATA_BASE);

    printf("Writing to inode0 data memory...\n");
    data_mem[0] = TEST_PATTERN1;
    data_mem[1] = TEST_PATTERN2;
    data_mem[8] = TEST_PATTERN3;  // Next 256-bit word

    uint32_t data0 = data_mem[0];
    uint32_t data1 = data_mem[1];
    uint32_t data8 = data_mem[8];

    printf("Data[0]: wrote 0x%08x, read 0x%08x %s\n",
           TEST_PATTERN1, data0, (data0 == TEST_PATTERN1) ? "✓" : "✗");
    printf("Data[1]: wrote 0x%08x, read 0x%08x %s\n",
           TEST_PATTERN2, data1, (data1 == TEST_PATTERN2) ? "✓" : "✗");
    printf("Data[8]: wrote 0x%08x, read 0x%08x %s\n",
           TEST_PATTERN3, data8, (data8 == TEST_PATTERN3) ? "✓" : "✗");
}

void test_state_machine() {
    printf("\n=== Testing State Machine ===\n");

    // Read current state
    uint32_t state = imcflow_regs[REG_STATE/4];
    printf("Current state: %u\n", state);

    // Try to trigger simulation by writing to CMD register
    printf("Writing RUN command to trigger simulation...\n");
    imcflow_regs[REG_CMD/4] = STATE_RUN;

    // Read state after command
    usleep(1000);  // Give some time for processing
    state = imcflow_regs[REG_STATE/4];
    printf("State after RUN command: %u\n", state);

    // Read command register
    uint32_t cmd = imcflow_regs[REG_CMD/4];
    printf("Command register: %u\n", cmd);
}

void test_multiple_nodes() {
    printf("\n=== Testing Multiple Interface Nodes ===\n");

    // Test inode1 instruction memory
    volatile uint32_t *inst1_mem = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE1_INST_BASE);

    printf("Writing to inode1 instruction memory...\n");
    inst1_mem[0] = ~TEST_PATTERN1;  // Inverted pattern

    uint32_t inst1 = inst1_mem[0];
    printf("INode1 Inst[0]: wrote 0x%08x, read 0x%08x %s\n",
           ~TEST_PATTERN1, inst1, (inst1 == ~TEST_PATTERN1) ? "✓" : "✗");

    // Verify inode0 still has original data
    volatile uint32_t *inst0_mem = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE0_INST_BASE);
    uint32_t inst0 = inst0_mem[0];
    printf("INode0 Inst[0]: read 0x%08x (should be unchanged) %s\n",
           inst0, (inst0 == TEST_PATTERN1) ? "✓" : "✗");
}

int main() {
    printf("ImcFlow Device Test Program\n");
    printf("===========================\n");

    if (map_imcflow_device() != 0) {
        printf("Failed to map ImcFlow device\n");
        return 1;
    }

    printf("Successfully mapped ImcFlow device\n");

    // Run all tests
    test_register_access();
    test_instruction_memory();
    test_data_memory();
    test_multiple_nodes();
    test_state_machine();

    printf("\n=== Test Summary ===\n");
    printf("ImcFlow device testing completed.\n");
    printf("Check output above for individual test results.\n");

    return 0;
}
