# ImcFlow RTL Co-Simulation Setup

## What We've Built

This directory now contains a complete RTL co-simulation infrastructure for ImcFlow with gem5:

### Phase 1: DPI Testbench ✅
- **testbench_imcflow_gem5.sv**: Main testbench that:
  - Accepts socket connections from gem5 on port 9999
  - Converts MMIO transactions to AXI4 protocol
  - Drives the `imcflow_with_axi` RTL module
  - Includes clock/reset generation and AXI master driver

### Phase 2: Compilation Scripts ✅
- **Makefile**: VCS compilation with DPI-C support
- **rtl.f**: Complete ImcFlow RTL source file list
- **tb.f**: Testbench and verification infrastructure
- **tech.f**: Technology library files (memory models)
- **parameters.txt**: VCS parameter override file

### Phase 4: Runner Script ✅
- **run.sh**: Automated co-simulation launcher that:
  - Compiles VCS simulation if needed
  - Starts VCS RTL simulation in background
  - Launches gem5 with ImcflowPIOSocket device
  - Collects and displays results

## Quick Start

### Prerequisites
```bash
# Ensure environment variables are set
export IMCFLOW_DIR=/root/project/imcflow
export GEM5_HOME=/root/project/imcflow/pmap/ISA_sim/gem5
export GPIO_MODEL_DIR=/path/to/gpio/models  # Update as needed
```

### Compile Only
```bash
make compile
```

### Run Co-Simulation
```bash
# Simple run
./run.sh tvm_host_runner no one_conv

# With GDB support
./run.sh tvm_host_runner yes one_conv
```

### Manual Two-Terminal Workflow
```bash
# Terminal 1: Start VCS simulation
make run

# Terminal 2: Launch gem5 (in another terminal)
cd $GEM5_HOME
./build/X86/gem5.opt configs/imcflow/run_imcflow_socket.py \
    --binary /path/to/binary --test-name test1
```

## File Structure

```
rtl_runner/
├── testbench_imcflow_gem5.sv    # Main DPI-C + AXI testbench
├── Makefile                      # VCS compilation with DPI-C
├── rtl.f                         # RTL source file list
├── tb.f                          # Testbench file list
├── tech.f                        # Technology libraries
├── parameters.txt                # VCS parameters
├── run.sh                        # Automated runner script
└── README.md                     # Original overview (this is SETUP.md)
```

## Key Features

1. **Socket Communication**: DPI-C socket server on port 9999
2. **AXI Protocol**: Automatic conversion of MMIO → AXI4 transactions
3. **RTL Accuracy**: Cycle-accurate simulation with actual ImcFlow RTL
4. **gem5 Integration**: Works with ImcflowPIOSocket device in gem5
5. **Automated Workflow**: Single command to run full co-simulation

## Next Steps (Phase 3: Integration Testing)

1. **Simple Register Access**: Test basic read/write to ImcFlow registers
2. **Memory Operations**: Test instruction/data memory access
3. **TVM Workloads**: Run actual TVM-generated code
4. **Validation**: Compare results with py_runner (Python functional model)

## Architecture Reminder

```
TVM Host Binary (x86)
        ↓
    gem5 CPU + System
        ↓
ImcflowPIOSocket Device (gem5)
        ↓ (TCP Socket: 127.0.0.1:9999)
DPI-C Socket Server (VCS - testbench_imcflow_gem5.sv)
        ↓ (AXI4 Master)
ImcFlow RTL (imcflow_with_axi.sv)
```

## Troubleshooting

### VCS Compilation Errors
- Check `IMCFLOW_DIR` environment variable
- Verify all RTL files exist: `cat rtl.f | xargs ls -l`
- Check for missing technology libraries in `tech.f`

### Socket Connection Issues
- Ensure VCS simulation starts before gem5
- Check port 9999 is not in use: `netstat -an | grep 9999`
- Verify socket server initializes: check `vcs_sim.log`

### AXI Transaction Errors
- Enable waveform dumping in testbench
- Use Verdi: `make verdi`
- Check address mapping (lower 12 bits used)

## Build Artifacts

After compilation:
- `simv_imcflow_gem5`: VCS executable
- `simv_imcflow_gem5.daidir/`: VCS simulation database
- `csrc/`: Generated C++ sources
- `vcs_sim.log`: VCS simulation log
- `logs/`: Test output logs
