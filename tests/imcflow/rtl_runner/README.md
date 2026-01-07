# ImcFlow RTL Co-Simulation Runner

Run ImcFlow RTL simulations with gem5 via socket communication. Execute TVM-compiled neural network workloads on cycle-accurate RTL hardware.

## Quick Start

### Run TVM Workload on RTL

```bash
./run.sh tvm_host_runner no one_conv
```

This will:
1. Compile VCS RTL simulation (if needed) → `build/`
2. Copy TVM binaries and MLF from TVM build directory
3. Start VCS RTL server on port 9999
4. Run gem5 with TVM binary executing on ImcFlow RTL
5. Save logs to `logs/` and waveforms to `imcflow_gem5.fsdb`

### Run MMIO Communication Test

```bash
./test_mmio_communication.sh
```

Verifies basic gem5 ↔ VCS socket communication with MMIO read/write operations.

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

## Usage

### Running TVM Workloads

**Basic usage:**
```bash
./run.sh <binary_name> <gdb_mode> [test_name]
```

**Examples:**
```bash
# Run one_conv workload
./run.sh tvm_host_runner no one_conv

# Run resnet8 with GDB debugging
./run.sh tvm_host_runner yes resnet8

# Run with custom test name
./run.sh tvm_host_runner no my_custom_test
```

**What happens:**
1. **Copy binaries**: `tvm_host_runner` and `mlf/` from `~/project/tvm/tvm_practice/test_imcflow/codegen/host_binary_make/build/`
2. **Compile VCS**: If `build/simv_imcflow_gem5` doesn't exist
3. **Start VCS**: RTL simulator listening on port 9999
4. **Run gem5**: Executes TVM binary with `run_imcflow_rtl.py` config
5. **Cleanup**: Terminates VCS and saves logs

**Output files:**
```
logs/
├── vcs_sim.log          # RTL simulation output
├── gem5_output.log      # gem5 execution log
└── fsim_logs/           # Detailed transaction logs (when FSIM enabled)
m5out/                   # gem5 statistics
imcflow_gem5.fsdb        # Waveform database (for Verdi)
test_outputs/<test_name>/ # Test results
```

### MMIO Communication Test

**Usage:**
```bash
./test_mmio_communication.sh
```

**What it tests:**
- Write 8 test values to RTL via MMIO (offsets 0x500-0x51C)
- Read values back and verify correctness
- Test mixed read/write operations
- Verify ImcFlow state polling mechanism

**Expected output:**
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

### Polling Mode and Auto-Acknowledgment

**Design Decision**: This testbench uses **polling** instead of interrupt-based synchronization.

**How it works**:
- gem5 host code polls `STATE_REG_IDX` register until ImcFlow returns to `IDLE`
- No interrupt handler is present in gem5 syscall-emulation mode
- ImcFlow RTL still generates `interrupt_o` signals internally
- **Testbench automatically acknowledges interrupts** to keep RTL state machine healthy

**Auto-Ack Logic** (in `testbench_imcflow_gem5.sv`):
```systemverilog
// Auto-acknowledge interrupts one cycle after they are raised
always @(posedge clk or negedge rstn) begin
  if (!rstn) begin
    interrupt_ack_i <= 1'b0;
    interrupt_o_delayed <= 1'b0;
  end else begin
    interrupt_o_delayed <= interrupt_o;
    // Generate ack pulse when interrupt rises
    interrupt_ack_i <= interrupt_o && !interrupt_o_delayed;
  end
end
```

**Code Generation**: TVM's `ext_codegen.py` generates polling code when `USE_POLLING = True`:
- Adds `wait_for_idle()` function to generated kernels
- Inserts polling after `SET_PROGRAM_CODE` and `SET_RUN_CODE`
- Set `USE_POLLING = False` to disable polling (interrupt-based flow)

**Why polling instead of interrupts?**
- gem5 syscall-emulation (SE) mode doesn't support device interrupts
- Polling is simpler for co-simulation with socket communication
- Future: Full-system (FS) mode could use real interrupt handling

### Signal Initialization Workarounds

**IMCE sync_reg_data 'x' Values After Reset**:

**Problem**: IMCE modules don't initialize their `syn_reg_data_o` outputs during reset, causing 'x' values in the controller's `sync_reg_data_i[20]` array:
- Indices **0, 5, 10, 15** → INODE outputs (properly initialized to 0)
- Indices **1-4, 6-9, 11-14, 16-19** → IMCE outputs (remain 'x')

**Root Cause**: IMCE `syn_reg_data_o` is only driven during flag write operations from the IMCE FSM, not during reset. Since the RTL is taped out, this cannot be fixed.

**Solution**: Testbench forces IMCE `syn_reg_data_o` signals to 0 during reset, then releases them after reset completes:
```systemverilog
// Force during reset
for (int row = 0; row < 4; row++) begin
  for (int col = 0; col < 4; col++) begin
    force u_imcflow_with_axi.u_imcflow_impl.core_row[row].core_col[col+1]
          .imce_node.imce.syn_reg_data_o = '0;
  end
end

// Release after reset
wait(rstn == 1'b1); repeat(10) @(posedge clk);
for (int row = 0; row < 4; row++) begin
  for (int col = 0; col < 4; col++) begin
    release u_imcflow_with_axi.u_imcflow_impl.core_row[row].core_col[col+1]
            .imce_node.imce.syn_reg_data_o;
  end
end
```

This is safe because these signals are only meaningful after the first flag write operation.

### RTL Files

ImcFlow RTL: `~/project/imcflow/pmap/modules/top/source/`
- `imcflow_with_axi.sv` - Top-level AXI wrapper
- `imcflow_impl.sv` - Core implementation
- File lists: `rtl.f`, `tb.f`, `tech.f`

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
│   ├── gem5_output.log            # gem5 execution output
│   └── fsim_logs/                 # Detailed transaction logs
│
├── binaries/                      # Test binaries (generated)
├── mlf/                           # Model Library Format (generated)
├── m5out/                         # gem5 stats/outputs (generated)
├── test_outputs/                  # Test results (generated)
│
├── testbench_imcflow_gem5.sv     # Main SystemVerilog testbench
├── Makefile                       # VCS compilation
├── rtl.f, tb.f, tech.f           # File lists for VCS
├── test_mmio_communication.sh    # MMIO test script
├── run.sh                         # TVM workload runner
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

# Run TVM workload on RTL
./run.sh tvm_host_runner no one_conv     # Run TVM workload
./run.sh tvm_host_runner yes resnet8     # Run with GDB debugging

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

**No FSIM logs generated:**
- Verify compilation with `-DFSIM` flag in Makefile
- Check `logs/fsim_logs/` directory is created
- Look for log files matching module hierarchy names
