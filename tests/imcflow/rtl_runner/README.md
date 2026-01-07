# ImcFlow RTL Co-Simulation Runner

DPI-C integrated testbench for running ImcFlow RTL simulations with gem5 via socket communication.

## Status at a Glance

| Phase | Status | Description |
|-------|--------|-------------|
| **Phase 1: MMIO Communication** | ✅ **COMPLETE** | gem5 ↔ VCS socket working |
| **Phase 2: Controller Registers** | ⏳ TODO | Control ImcFlow from gem5 |
| **Phase 3: Memory Integration** | ⏳ TODO | IMEM/DMEM access |
| **Phase 4: TVM Workloads** | ⏳ TODO | Run neural networks |
| **Phase 5: Full Validation** | ⏳ TODO | Production ready |

## Quick Start

```bash
# Run the MMIO communication test
./test_mmio_communication.sh

# The script will:
# 1. Compile VCS RTL simulation (if needed) → build/
# 2. Start VCS server on port 9999
# 3. Run gem5 with MMIO test binary
# 4. Show results and save logs to logs/
```

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

## How test_mmio_communication.sh Works

### Current Test (MMIO Communication Verification)

**Test Binary**: `mmio_communication_test.c` from `tests/test-progs/imcflow/`

**What it tests**:
1. **Write 8 values** to RTL via MMIO (offsets 0x500-0x51C)
   - Values: 0xDEADBEEF, 0xCAFEBABE, 0x12345678, etc.
2. **Read 8 values** back from RTL memory
3. **Verify** all values match (write-then-read echo test)
4. **Mixed operations** - alternating write/read to test bidirectional flow

**Flow Diagram**:
```
gem5 (x86 CPU)
    ↓ MMIO write/read to 0x80000000
ImcflowPIOSocket (C++ device in gem5)
    ↓ TCP socket (127.0.0.1:9999)
DPI-C Socket Server (dpi_socket_server.cpp)
    ↓ SystemVerilog DPI-C functions
testbench_imcflow_gem5.sv
    ↓ AXI4 transactions
ImcFlow RTL (imcflow_with_axi.sv)
    ↓ TCDM memory interface
On-chip memory arrays (read/write data)
```

**Expected Output**:
```
--- Test 1: Writing data to VCS ---
[gem5 → VCS] WRITE: offset=0x0500, value=0xdeadbeef
...

--- Test 2: Reading data from VCS ---
[VCS → gem5] READ:  offset=0x0500, value=0xdeadbeef
...

--- Test 3: Verification ---
Read value 1: 0xdeadbeef ✓
...
✓ TEST PASSED
```

### ✅ What Works Now (Phase 1 Complete)

- ✅ VCS RTL compilation with DPI-C socket server
- ✅ gem5 ↔ VCS socket communication (port 9999)
- ✅ MMIO transactions (write/read) through RTL
- ✅ AXI4 protocol conversion in testbench
- ✅ Data verification (echo test passes)
- ✅ Organized directory structure (`build/`, `logs/`)
- ✅ Automated test script with logging

## Technical Details

### Transaction Protocol

**12-byte Binary Protocol** between gem5 and VCS:
```c
struct Transaction {
    uint8_t is_write;    // 1 = write, 0 = read
    uint8_t padding[3];  // Compiler alignment
    uint32_t addr;       // Byte address (offset from MMIO base)
    uint32_t data;       // Data word
};
```

### DPI-C Interface

SystemVerilog testbench uses DPI-C functions from `dpi_socket_server.cpp`:

```c
socket_server_init(9999)           // Initialize server
socket_server_accept()             // Wait for gem5
socket_has_transaction()           // Poll for data
socket_recv_transaction(...)       // Receive MMIO request
socket_send_response(data)         // Send read response
socket_server_close()              // Cleanup
```

### FSIM Logging

**When compiled with `-DFSIM` (enabled in Makefile)**, RTL modules create detailed transaction logs using `$fdisplay`:

**Log File Location**: `logs/fsim_logs/{module_name}.log`

**What gets logged**:
- Interface node memory transactions (READ/WRITE operations)
- Instruction memory accesses (IMEM)
- Policy updates
- Pipeline stages (ID_EX, MEM, WB)
- Router and flow interface operations

**Example log files** (auto-created during simulation):
```
logs/fsim_logs/
├── run.log                                          # Main simulation log
├── testbench_imcflow_gem5.u_imcflow_with_axi...    # Module-specific logs
└── ...
```

**How it works**:
- `utils::ModuleLogger` instances in RTL use `utils::FdManager` singleton
- Testbench calls `fdm.set_log_file_path("logs/fsim_logs")` during initialization
- Each module creates its own log file: `{log_file_path}/{module_name}.log`
- Files are created automatically when first `$fdisplay()` is executed

**Example from `imem_intf_node.sv`**:
```systemverilog
`ifdef FSIM
  utils::ModuleLogger logger = new($sformatf("%m"));

  initial begin
    while (1) begin
      @(posedge clk_i);
      if (~csn & we) begin
        $fdisplay(logger.get_fd(), "[%t] INST WRITEN | addr:%8d | data:%8d",
                  $time, rw_addr, wr_data);
      end
    end
  end
`endif
```

### RTL Files

ImcFlow RTL: `~/project/imcflow/pmap/modules/top/source/`
- `imcflow_with_axi.sv` - Top-level AXI wrapper
- `imcflow_impl.sv` - Core implementation
- File lists: `rtl.f`, `tb.f`, `tech.f`

## Remaining Phases

### Phase 2: Controller Register Interface (TODO)

**Goal**: Enable gem5 to configure and control ImcFlow accelerator

**Tasks**:
- [ ] Map ImcFlow controller registers to MMIO addresses
- [ ] Implement register write/read in testbench
- [ ] Test register configuration from gem5
  - Start/stop control
  - Status polling
  - Configuration registers

**Test**: Write a simple test that configures ImcFlow and reads status

---

### Phase 3: Memory Access Integration (TODO)

**Goal**: Allow ImcFlow to access instruction/data memory

**Current State**: MMIO transactions work, but ImcFlow needs access to:
- Instruction memory (IMEM) - program for IMC cores
- Data memory (DMEM) - input/output data

**Tasks**:
- [ ] Understand ImcFlow memory map and requirements
- [ ] Implement memory loading mechanism (IMEM/DMEM)
- [ ] Test memory read/write from ImcFlow perspective
- [ ] Verify memory coherency

**Reference**: Check `py_runner` for memory initialization patterns

---

### Phase 4: TVM Workload Execution (TODO)

**Goal**: Run actual TVM-generated workloads on ImcFlow RTL

**Tasks**:
- [ ] Port TVM binary execution from `py_runner` to `rtl_runner`
- [ ] Implement workload loading sequence:
  1. Load instructions to IMEM
  2. Load input data to DMEM
  3. Configure controller
  4. Start execution
  5. Wait for completion
  6. Read results
- [ ] Create test with simple TVM workload (e.g., `one_conv`)
- [ ] Verify output matches Python functional model

**Test Binary**: Use existing TVM binaries from `~/project/tvm/tvm_practice/test_imcflow/`

---

### Phase 5: Full Integration & Validation (TODO)

**Goal**: Production-ready RTL co-simulation

**Tasks**:
- [ ] Performance profiling (cycle counts, timing)
- [ ] Waveform debugging support (Verdi integration)
- [ ] Automated regression testing
- [ ] Compare RTL vs Python model results
- [ ] Documentation and examples

**Success Criteria**:
- ✓ TVM workloads run successfully on RTL
- ✓ Results match Python functional model
- ✓ Performance metrics are accurate

## Directory Structure

```
rtl_runner/
├── build/                          # VCS build artifacts (generated)
│   ├── simv_imcflow_gem5          # Compiled RTL simulator
│   ├── csrc/                      # C++ intermediates
│   └── *.daidir/                  # VCS database
│
├── logs/                          # Simulation logs (generated)
│   ├── vcs_sim.log                # RTL simulation output
│   └── gem5_output.log            # gem5 execution output
│
├── binaries/                      # Test binaries (generated)
├── m5out/                         # gem5 stats/outputs (generated)
├── test_outputs/                  # Test results (generated)
│
├── testbench_imcflow_gem5.sv     # Main SystemVerilog testbench
├── Makefile                       # VCS compilation
├── rtl.f, tb.f, tech.f           # File lists for VCS
├── test_mmio_communication.sh    # MMIO test script
├── run.sh                         # Generic runner (for TVM)
└── README.md                      # This file
```

**Note**: Directories marked *(generated)* are created automatically and ignored by git.

## Commands

```bash
# Compile RTL simulation
make compile                       # → build/simv_imcflow_gem5

# Clean build artifacts
make clean                         # Clean logs
make clean_all                     # Clean everything

# Run MMIO communication test
./test_mmio_communication.sh       # Full test with logging

# Manual VCS run (advanced)
build/simv_imcflow_gem5            # Start VCS server manually
```

## Key Differences from py_runner

| Aspect | py_runner | rtl_runner |
|--------|-----------|------------|
| Backend | Python functional model | VCS RTL simulation |
| Device | ImcflowPIO | ImcflowPIOSocket |
| Communication | Direct function calls | TCP socket (port 9999) |
| Accuracy | Functional only | Cycle-accurate RTL |
| Speed | Very fast (~seconds) | Slow (~minutes to hours) |

## Reference Documentation

- gem5 Socket Implementation: `~/project/imcflow/pmap/ISA_sim/gem5/docs/imcflow/`
- DPI Example: `~/project/imcflow/pmap/ISA_sim/gem5/dpi_example/socket_test/`
- Previous Testbench: `~/project/imcflow/pmap/modules/top/source/tb/tb_imcflow_with_axi.sv`

## Troubleshooting

**VCS won't connect to gem5:**
- Check VCS is listening: `tail -f logs/vcs_sim.log`
- Verify port 9999 is not in use: `netstat -an | grep 9999`

**Compilation errors:**
- Ensure `IMCFLOW_DIR` environment variable is set
- Check RTL file paths in `rtl.f`, `tb.f`, `tech.f`

**Test hangs:**
- Check both gem5 and VCS logs in `logs/` directory
- VCS may need more initialization time (increase sleep in test script)
