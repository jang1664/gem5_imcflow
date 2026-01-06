# ImcFlow RTL Co-Simulation Runner

DPI-C integrated testbench for running ImcFlow RTL simulations with gem5 via socket communication.

## Overview

This directory contains the infrastructure to replace the previous CPU testbench model (`sys_test.c` in fsim) with gem5, enabling complete system-level simulation with actual RTL hardware.

**Goal**: Integrate ImcFlow RTL (from `~/project/imcflow/pmap/modules/top/source/`) with gem5 to create a full system co-simulation environment.

## Architecture

```
TVM Host Binary (x86)
        ↓
    gem5 CPU + System
        ↓
ImcflowPIOSocket Device (gem5)
        ↓ (TCP Socket: 127.0.0.1:9999)
DPI-C Socket Server (VCS)
        ↓
SystemVerilog Testbench
        ↓
ImcFlow RTL (imcflow_with_axi.sv)
```

## Implementation Status

Based on recent commits (gem5 repository):

### ✅ Completed
- **Socket Communication Infrastructure** (commit 7b0b9e8b0b)
  - Fixed struct alignment between gem5 and VCS
  - Corrected address calculation in SystemVerilog DPI
  - 12-byte transaction protocol with proper padding

- **ImcflowPIOSocket Device** (commits 6a1510b6db, f93e226a12)
  - C++ implementation with TCP socket client
  - Python configuration module
  - MMIO address range: 0x80000000 - 0x80041000 (260KB)

- **DPI-C Server Implementation** (commit 7b0b9e8b0b)
  - Socket server functions in `dpi_socket_server.cpp`
  - Testbench integration in `testbench_socket.sv`
  - Memory model with read/write operations

- **Error Handling** (commit b60cdf592e)
  - Fail-fast behavior on VCS connection failures
  - Proper panic() on socket errors for reliable co-simulation

- **Performance Optimization** (commit 9f7e98bae5)
  - Support for gem5.fast for faster simulation
  - Automatic fallback to gem5.opt if fast version unavailable

### 🔄 Previous Functional Simulation (Reference)

Location: `~/project/imcflow/pmap/modules/top/fsim/imcflow_with_axi/`

**Key Components**:
- `sys_test.c` - ARM CPU testbench (being replaced by gem5)
- `tb_imcflow_with_axi.sv` - AXI testbench wrapper
- `Makefile` - VCS compilation with AXI/TCDM configuration
- RTL file lists: `rtl.f`, `tb.f`, `tech.f`

**Migration Path**: Replace `sys_test.c` CPU model with gem5 + DPI-C socket bridge

## RTL Source Location

ImcFlow RTL modules: `~/project/imcflow/pmap/modules/top/source/`

**Key RTL Files**:
- `imcflow_with_axi.sv` - Top-level module with AXI interface
- `imcflow_impl.sv` - Core ImcFlow implementation
- `imcflow.sv` - Main accelerator logic
- `controller.sv` - State machine controller
- `axi/` - AXI protocol modules
- `tcdm/` - TCDM memory interface
- `tb/` - Testbench modules

## Transaction Protocol

**12-byte Binary Protocol** (fixed in commit 7b0b9e8b0b):
```c
struct Transaction {
    uint8_t is_write;    // 1 = write, 0 = read
    uint8_t padding[3];  // Compiler alignment padding
    uint32_t addr;       // Byte address (offset from base)
    uint32_t data;       // Data word (write) or response (read)
};
```

**Address Calculation**:
```systemverilog
// Extract word address from byte address using bit slicing
logic [11:0] byte_offset = addr[11:0];        // Lower 12 bits (4KB range)
int unsigned word_addr = {20'b0, byte_offset[11:2]}; // Bits [11:2]
```

## DPI-C Interface Functions

Located in `~/project/imcflow/pmap/ISA_sim/gem5/dpi_example/socket_test/dpi_socket_server.cpp`

```c
int socket_server_init(int port);          // Initialize TCP server
int socket_server_accept();                 // Accept client connection (blocking)
int socket_has_transaction();               // Check for pending data (non-blocking)
int socket_recv_transaction(output int is_write,
                           output int addr,
                           output int data);  // Receive transaction
int socket_send_response(input int data);   // Send read response
void socket_server_close();                 // Cleanup
```

## Next Steps for RTL Integration

### Phase 1: Adapt DPI Testbench for ImcFlow RTL
1. Copy `testbench_socket.sv` template to rtl_runner
2. Replace simple memory model with ImcFlow AXI driver
3. Map MMIO transactions to AXI4 protocol
4. Connect to `imcflow_with_axi` RTL module

### Phase 2: Create Compilation Scripts
1. Adapt Makefile from `fsim/imcflow_with_axi/`
2. Create RTL file list including:
   - ImcFlow RTL sources (`rtl.f`)
   - AXI modules
   - DPI testbench (`testbench_imcflow_gem5.sv`)
3. Add VCS compilation flags for DPI-C

### Phase 3: Integration Testing
1. Start with simple register access tests
2. Progress to instruction/data memory operations
3. Verify full TVM workload execution
4. Compare results with Python functional model

### Phase 4: Runner Script
1. Create `run.sh` similar to `py_runner/run.sh`
2. Launch VCS simulation in background
3. Run gem5 with TVM binary
4. Collect and verify results

## Reference Documentation

- gem5 Socket Implementation: `~/project/imcflow/pmap/ISA_sim/gem5/docs/imcflow/`
- DPI Example: `~/project/imcflow/pmap/ISA_sim/gem5/dpi_example/socket_test/`
- Previous Testbench: `~/project/imcflow/pmap/modules/top/source/tb/tb_imcflow_with_axi.sv`

## Key Differences from py_runner

| Aspect | py_runner | rtl_runner |
|--------|-----------|------------|
| Backend | Python functional model | VCS RTL simulation |
| Device | ImcflowPIO | ImcflowPIOSocket |
| Communication | Direct function calls | TCP socket (port 9999) |
| Latency | Minimal | Includes RTL cycle accuracy |
| Startup | Instantaneous | VCS initialization required |

## Recent Bug Fixes (from git log)

1. **Struct Alignment** (7b0b9e8b0b): Fixed padding causing address scrambling
2. **Address Calculation** (7b0b9e8b0b): Changed to bit slicing for DPI compatibility
3. **Error Handling** (b60cdf592e): Reverted to panic() for connection failures
4. **Performance** (9f7e98bae5): Added gem5.fast support
5. **Logging** (c3c67060a0): Improved DPI-C READ message formatting
