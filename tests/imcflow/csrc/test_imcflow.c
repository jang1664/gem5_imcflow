#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdlib.h>

// ImcFlow device base address (should match gem5 config)
#define IMCFLOW_BASE    0x80000000UL
#define IMCFLOW_SIZE    0x493E0UL // 300000, must match --imc-size default

// Register offsets (based on params.py)
#define REG_STATE       0x00    // REG_STATE_ID = 0
#define REG_CMD         0x04    // REG_CMD_ID_BASE = 1
#define REG_INODE_PC0   0x08    // REG_INODE_PC_ID_BASE = 2
#define REG_INODE_PC1   0x0C
#define REG_INODE_PC2   0x10
#define REG_INODE_PC3   0x14

// Memory regions (based on address map)
#define INODE0_INST_BASE  128      // inode0 instruction memory
#define INODE0_DATA_BASE  1152     // inode0 data memory (0x80 + 0x400)
#define INODE1_INST_BASE  66688   // inode1 instruction memory
#define INODE1_DATA_BASE  67712   // inode1 data memory
#define INODE2_INST_BASE  133248   // inode1 instruction memory
#define INODE2_DATA_BASE  134272   // inode1 data memory
#define INODE3_INST_BASE  199808   // inode1 instruction memory
#define INODE3_DATA_BASE  200832   // inode1 data memory

// State values
#define STATE_IDLE      0
#define STATE_RUN       1
#define STATE_PROGRAM   2

// PC control flags (top 2 bits of PC register)
#define PC_FLAG_START_P0        (2U << 30) // 0b00...
#define PC_FLAG_START_P1        (0U << 30) // 0b01...
#define PC_FLAG_START_EXTERN    (1U << 30) // 0b10...
#define PC_VAL_MASK             (0x3FFFFFFF)

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

    // Test PC register writes with valid flags
    printf("Testing PC register writes with valid flags...\n");
    uint32_t pc_write_val0 = PC_FLAG_START_EXTERN | 0x1234;
    uint32_t pc_write_val1 = PC_FLAG_START_P1 | 0x5678;

    imcflow_regs[REG_INODE_PC0/4] = pc_write_val0;
    imcflow_regs[REG_INODE_PC1/4] = pc_write_val1;

    uint32_t pc0 = imcflow_regs[REG_INODE_PC0/4];
    uint32_t pc1 = imcflow_regs[REG_INODE_PC1/4];

    printf("PC0: wrote 0x%08x, read 0x%08x %s\n",
           pc_write_val0, pc0, (pc0 == pc_write_val0) ? "✓" : "✗");
    printf("PC1: wrote 0x%08x, read 0x%08x %s\n",
           pc_write_val1, pc1, (pc1 == pc_write_val1) ? "✓" : "✗");
}

void test_instruction_memory() {
    printf("\n=== Testing Instruction Memory ===\n");

    // Test inode0 instruction memory
    volatile uint32_t *inst_mem = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE0_INST_BASE);
    printf("Writing to inode0 instruction memory...\n");
    inst_mem[0] = 0; //NOP
    inst_mem[1] = 28; // INTERRUPT
    inst_mem[2] = 33; // DONE
    inst_mem[3] = 34; // HALT

    uint32_t inst0 = inst_mem[0];
    uint32_t inst1 = inst_mem[1];
    uint32_t inst2 = inst_mem[2];
    uint32_t inst3 = inst_mem[3];

    printf("Inst[0]: wrote 0x%08x, read 0x%08x %s\n",
           0, inst0, (inst0 == 0) ? "✓" : "✗");
    printf("Inst[1]: wrote 0x%08x, read 0x%08x %s\n",
           28, inst1, (inst1 == 28) ? "✓" : "✗");
    printf("Inst[2]: wrote 0x%08x, read 0x%08x %s\n",
           33, inst2, (inst2 == 33) ? "✓" : "✗");
    printf("Inst[3]: wrote 0x%08x, read 0x%08x %s\n",
           34, inst3, (inst3 == 34) ? "✓" : "✗");

    inst_mem = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE1_INST_BASE);
    printf("Writing to inode1 instruction memory...\n");
    inst_mem[0] = 0; //NOP
    inst_mem[1] = 28; // INTERRUPT
    inst_mem[2] = 33; // DONE
    inst_mem[3] = 34; // HALT

    inst_mem = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE2_INST_BASE);
    printf("Writing to inode2 instruction memory...\n");
    inst_mem[0] = 0; //NOP
    inst_mem[1] = 28; // INTERRUPT
    inst_mem[2] = 33; // DONE
    inst_mem[3] = 34; // HALT

    inst_mem = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE3_INST_BASE);
    printf("Writing to inode3 instruction memory...\n");
    inst_mem[0] = 0; //NOP
    inst_mem[1] = 28; // INTERRUPT
    inst_mem[2] = 33; // DONE
    inst_mem[3] = 34; // HALT
}

void test_data_memory() {
    printf("\n=== Testing Data Memory ===\n");

    // Test inode0 data memory (256-bit wide, but we'll access as 32-bit words)
    // data will be automatically duplicated across 256 bit width
    // ex. data_mem[0] = 0xDEADBEEF => data_mem[0..7] = 0xDEADBEEF
    // need zero padding 32 bits to 256 bits (8 words)
    volatile uint32_t *data_mem = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE0_DATA_BASE);

    printf("Writing to inode0 data memory...\n");
    data_mem[0] = TEST_PATTERN1;
    // data_mem[0] will be overwritted by TEST_PATTERN2
    data_mem[1] = TEST_PATTERN2;
    data_mem[2] = TEST_PATTERN3;  // Next 256-bit word
    data_mem[3] = 0x00000000;
    data_mem[4] = 0x00000000;
    data_mem[5] = TEST_PATTERN1;
    data_mem[6] = TEST_PATTERN2;
    data_mem[7] = TEST_PATTERN3;

    uint32_t data0 = data_mem[0];
    uint32_t data1 = data_mem[1];
    uint32_t data2 = data_mem[2];
    uint32_t data3 = data_mem[3];
    uint32_t data4 = data_mem[4];
    uint32_t data5 = data_mem[5];
    uint32_t data6 = data_mem[6];
    uint32_t data7 = data_mem[7];

    printf("Data[0]: wrote 0x%08x, read 0x%08x %s\n",
           TEST_PATTERN1, data0, (data0 == TEST_PATTERN1) ? "✓" : "✗");
    printf("Data[1]: wrote 0x%08x, read 0x%08x %s\n",
           TEST_PATTERN2, data1, (data1 == TEST_PATTERN2) ? "✓" : "✗");
    printf("Data[2]: wrote 0x%08x, read 0x%08x %s\n",
           TEST_PATTERN3, data2, (data2 == TEST_PATTERN3) ? "✓" : "✗");
    printf("Data[3]: wrote 0x%08x, read 0x%08x %s\n",
           0x00000000, data3, (data3 == 0x00000000) ? "✓" : "✗");
    printf("Data[4]: wrote 0x%08x, read 0x%08x %s\n",
           0x00000000, data4, (data4 == 0x00000000) ? "✓" : "✗");
    printf("Data[5]: wrote 0x%08x, read 0x%08x %s\n",
           TEST_PATTERN1, data5, (data5 == TEST_PATTERN1) ? "✓" : "✗");
    printf("Data[6]: wrote 0x%08x, read 0x%08x %s\n",
           TEST_PATTERN2, data6, (data6 == TEST_PATTERN2) ? "✓" : "✗");
    printf("Data[7]: wrote 0x%08x, read 0x%08x %s\n",
           TEST_PATTERN3, data7, (data7 == TEST_PATTERN3) ? "✓" : "✗");
}

void test_state_machine() {
    printf("\n=== Testing State Machine ===\n");

    // Read current state
    uint32_t state = imcflow_regs[REG_STATE/4];
    printf("Current state: %u\n", state);

    // Set a valid PC value before running
    printf("Setting PC for inode0 to start at 0x0 with external flag\n");
    imcflow_regs[REG_INODE_PC0/4] = PC_FLAG_START_EXTERN | 0x0;
    imcflow_regs[REG_INODE_PC1/4] = PC_FLAG_START_EXTERN | 0x0;
    imcflow_regs[REG_INODE_PC2/4] = PC_FLAG_START_EXTERN | 0x0;
    imcflow_regs[REG_INODE_PC3/4] = PC_FLAG_START_EXTERN | 0x0;

    // Try to trigger simulation by writing to CMD register
    printf("Writing RUN command to trigger simulation...\n");
    imcflow_regs[REG_CMD/4] = STATE_RUN;

    // In a real simulation, we would wait for completion.
    // Here, we just check if the state changed.
    // The state should transition from RUN to IDLE by the DONE instruction
    state = imcflow_regs[REG_STATE/4];
    printf("State after RUN command: %u (expected: %u)\n", state, STATE_IDLE);

    // Command register should be cleared after being processed
    uint32_t cmd = imcflow_regs[REG_CMD/4];
    printf("Command register after RUN: %u (expected: %u)\n", cmd, STATE_IDLE);

    // Set back to IDLE for subsequent tests
    printf("Setting back to IDLE state...\n");
    imcflow_regs[REG_CMD/4] = STATE_IDLE;
    state = imcflow_regs[REG_STATE/4];
    printf("State after IDLE command: %u (expected: %u)\n", state, STATE_IDLE);
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
    test_data_memory();
    test_instruction_memory();
    test_state_machine();

    printf("\n=== Test Summary ===\n");
    printf("ImcFlow device testing completed.\n");
    printf("Check output above for individual test results.\n");

    return 0;
}
