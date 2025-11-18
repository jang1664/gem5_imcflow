# ImcFlow Test Programs

This directory contains test programs for the ImcFlow PIO device in gem5.

## Files

- `test_imcflow.c` - Main test program that exercises ImcFlow device functionality
- `Makefile` - Build system for native and X86 targets
- `README.md` - This file

## Test Program Features

The test program validates:

1. **Register Access**: Read/write to ImcFlow control registers
   - State register (read-only)
   - Command register (triggers simulation)
   - Interface node PC registers

2. **Instruction Memory**: Read/write to instruction memory regions
   - Tests multiple interface nodes
   - Verifies address isolation between nodes

3. **Data Memory**: Read/write to data memory regions
   - 256-bit wide memory accessed as 32-bit words
   - Tests memory region boundaries

4. **State Machine**: Command register interaction
   - Writing RUN command to trigger simulation
   - State transitions

5. **Multi-Node Testing**: Verifies multiple interface nodes work independently

## Building

```bash
# Build both native and X86 versions
make all

# Build just X86 version for gem5
make test_imcflow_x86

# Clean build artifacts
make clean
```

## Running with gem5

```bash
# From gem5 root directory, with activated environment
./build/X86/gem5.opt \
  pmap/ISA_sim/gem5/configs/imcflow/run_imcflow.py \
  --binary pmap/ISA_sim/gem5/tests/imcflow/test_imcflow_x86
```

## Expected Output

The test program will output results for each test section:
- ✓ indicates successful test
- ✗ indicates failed test

Sample output:
```
=== Testing Register Access ===
Initial state: 0 (expected: 0)
PC0: wrote 0xDEADBEEF, read 0xDEADBEEF ✓

=== Testing Instruction Memory ===
Inst[0]: wrote 0xDEADBEEF, read 0xDEADBEEF ✓
...
```

## Address Map

The test program uses these addresses (matching ImcFlow device mapping):

| Region | Base Address | Size | Description |
|--------|--------------|------|-------------|
| Registers | 0x80000000 | 32 bytes | Control registers |
| INode0 Inst | 0x80000080 | 1KB | Interface node 0 instructions |
| INode0 Data | 0x80000480 | 64KB | Interface node 0 data memory |
| INode1 Inst | 0x80010080 | 1KB | Interface node 1 instructions |
| INode1 Data | 0x80010480 | 64KB | Interface node 1 data memory |

## Debugging

If tests fail:
1. Check gem5 debug output for PIO transactions
2. Verify ImcFlow device is properly instantiated
3. Check address mapping matches between C code and Python simulator
4. Use gem5 debug flags: `--debug-flags=PIO,PioDevice`
