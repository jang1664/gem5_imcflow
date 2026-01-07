# ImcFlow Controller Register Memory Map

## Overview

The ImcFlow controller uses memory-mapped I/O (MMIO) for configuration and control. All registers are 32-bit wide and accessed via AXI4 interface from gem5.

**MMIO Base Address**: `0x80000000` (gem5 side)
**Register Base Offset**: `0x0000` (within ImcFlow address space)
**Address Width**: 20 bits (1MB addressable space)

## Register Map

| Offset | Register Name | Access | Width | Description |
|--------|---------------|--------|-------|-------------|
| 0x00   | STATE         | RO/WO* | 32b   | ImcFlow state register |
| 0x04   | CMD           | RW     | 32b   | Command register |
| 0x08   | INODE_PC[0]   | RW     | 32b   | Interface node 0 PC |
| 0x0C   | INODE_PC[1]   | RW     | 32b   | Interface node 1 PC |
| 0x10   | INODE_PC[2]   | RW     | 32b   | Interface node 2 PC |
| 0x14   | INODE_PC[3]   | RW     | 32b   | Interface node 3 PC |
| 0x18   | INTR_ID       | RO     | 32b   | Interrupt ID |
| 0x1C   | INTR_DONE     | RW     | 32b   | Interrupt done flag |

*RO = Read Only, RW = Read/Write, WO = Write Only (special case)

**Note**: STATE register is read-only normally, but can be written to in IDLE state to transition states.

## Register Descriptions

### 0x00: STATE Register (Read/Special Write)

**Purpose**: Controls ImcFlow accelerator state machine

**Read**: Returns current state
- `0x0` - IDLE state
- `0x1` - PROGRAM state (loading instructions/data)
- `0x2` - RUN state (executing)
- `0x3` - DELAY state (internal transition)

**Write** (only in IDLE state):
- Write `0x1` → Transition to PROGRAM state
- Write `0x2` → Transition to RUN state
- Other values → Stay in IDLE

**Usage**:
```c
// Read current state
uint32_t state = mmio_read(IMCFLOW_BASE + 0x00);

// Start execution (IDLE → RUN)
mmio_write(IMCFLOW_BASE + 0x00, 0x2);
```

---

### 0x04: CMD Register (Read/Write)

**Purpose**: General command register for ImcFlow control

**Fields**: Implementation-specific commands

**Usage**:
```c
mmio_write(IMCFLOW_BASE + 0x04, cmd_value);
```

---

### 0x08-0x14: INODE_PC[0:3] Registers (Read/Write)

**Purpose**: Program counter initialization for interface nodes (0-3)

**Format**:
- Bits [31:30] - PC Flags
  - `00` = PC_FLAG_PC_NO_RUN (don't run this node)
  - `01` = PC_FLAG_PC_RUN (run this node)
- Bits [29:0] - PC value

**Usage**:
```c
// Set node 0 PC to 0x100 and enable run
uint32_t pc = (0x01 << 30) | 0x100;
mmio_write(IMCFLOW_BASE + 0x08, pc);

// Disable node 1
mmio_write(IMCFLOW_BASE + 0x0C, 0x00000000);
```

---

### 0x18: INTR_ID Register (Read Only)

**Purpose**: Interrupt source identification

**Read**: Returns the ID of the interface node that generated the interrupt
- Valid when interrupt is pending
- Range: 0-3 (node index)

**Usage**:
```c
// Check which node interrupted
uint32_t intr_id = mmio_read(IMCFLOW_BASE + 0x18);
```

---

### 0x1C: INTR_DONE Register (Read/Write)

**Purpose**: Interrupt acknowledgement and enable

**Fields**:
- Bit [0] - Interrupt done flag
  - `1` = Interrupt handling complete (default)
  - `0` = Interrupt in progress

**Behavior**:
- Automatically cleared to `0` when interrupt is sent to CPU
- Software writes `1` to acknowledge interrupt completion

**Usage**:
```c
// Check interrupt status
uint32_t intr_done = mmio_read(IMCFLOW_BASE + 0x1C);

// Acknowledge interrupt
mmio_write(IMCFLOW_BASE + 0x1C, 0x1);
```

---

## State Machine Transitions

```
         IDLE
          |
          | Write STATE=0x1 (PROGRAM)
          | or STATE=0x2 (RUN)
          v
   PROGRAM / RUN
          |
          | (All nodes finish)
          v
        DELAY
          |
          v
         IDLE
```

**Key Behaviors**:
- STATE register write only works in IDLE state
- Writing PROGRAM or RUN starts execution
- Nodes specified by INODE_PC flags will run
- Automatic return to IDLE when all nodes finish

---

## Memory Regions

### Control Registers Region
- **Base**: `0x0000`
- **Size**: `0x80` (128 bytes)
- **Purpose**: Controller registers described above

### Instruction Memory (IMEM) Region
- **Base**: TBD (separate from control registers)
- **Purpose**: IMC core instruction storage
- **Access**: Write during PROGRAM state, read during execution

### Data Memory (DMEM) Region
- **Base**: TBD (separate from control registers)
- **Purpose**: Input/output data storage
- **Access**: Read/write during PROGRAM and RUN states

---

## Example: Basic Execution Flow

```c
#define IMCFLOW_BASE 0x80000000

// 1. Check we're in IDLE
uint32_t state = mmio_read(IMCFLOW_BASE + 0x00);
assert(state == 0x0);  // IDLE

// 2. Configure interface nodes
mmio_write(IMCFLOW_BASE + 0x08, (1<<30) | 0x0);  // Node 0: run from PC=0
mmio_write(IMCFLOW_BASE + 0x0C, (1<<30) | 0x0);  // Node 1: run from PC=0
mmio_write(IMCFLOW_BASE + 0x10, 0x00000000);     // Node 2: disabled
mmio_write(IMCFLOW_BASE + 0x14, 0x00000000);     // Node 3: disabled

// 3. Load program to IMEM (Phase 3)
// ... (memory loading not yet implemented)

// 4. Start execution
mmio_write(IMCFLOW_BASE + 0x00, 0x2);  // IDLE → RUN

// 5. Poll for completion
while(mmio_read(IMCFLOW_BASE + 0x00) != 0x0) {
    // Wait for return to IDLE
}

// 6. Check results
// ... (read from DMEM)
```

---

## Testing Strategy

### Phase 2 Tests (Register Access)
1. **test_reg_read_write.c** - Basic register R/W
   - Write and read back all RW registers
   - Verify read-only registers can't be written
   - Check default values

2. **test_state_transitions.c** - State machine
   - Test IDLE → PROGRAM transition
   - Test IDLE → RUN transition
   - Verify invalid transitions are ignored

3. **test_inode_pc.c** - PC configuration
   - Set PC values with different flags
   - Read back and verify

### Phase 3 Tests (Memory Integration)
- Memory loading and verification
- Full execution with simple programs

### Phase 4 Tests (TVM Workloads)
- Full neural network execution
