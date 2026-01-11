# ImcFlow Python Runner

Test runner for executing TVM-compiled models on gem5 with ImcFlow PIO device.

## Quick Start

```bash
./run.sh <binary_name> <gdb_mode> [test_name]
```

**Examples:**
```bash
./run.sh tvm_host_runner no one_conv
./run.sh tvm_host_runner yes resnet8
```

## Arguments

- `binary_name`: Name of the binary to run (default: `test_imcflow`)
- `gdb_mode`: Enable GDB and debug flags (`yes`/`no`, default: `no`)
- `test_name`: Test identifier for output directory (default: `default_test`)

## What It Does

1. Copies TVM host runner binary from `~/project/tvm/tvm_practice/test_imcflow/codegen/<test_name>/host_binary_make/build/`
2. Copies MLF (Model Library Format) directory
3. Creates output directory at `test_outputs/<test_name>/`
4. Runs gem5 simulation with the binary

## Directory Structure

```
py_runner/
├── binaries/          # Copied binary files
├── mlf/              # Model Library Format files
├── test_outputs/     # Simulation results per test
├── run.sh           # Main runner script
└── README.md        # This file
```

## Requirements

- Set `GEM5_HOME` environment variable to gem5 root directory
- TVM Python environment in PYTHONPATH (auto-configured by script)
- gem5 built for X86 (prefers `gem5.fast`, falls back to `gem5.opt`)

## Debug Mode

When `gdb_mode=yes`:
- Enables debug flags: `ImcflowPIO,AddrRanges`
- Launches gem5 with GDB support

When `gdb_mode=no`:
- No debug flags for faster execution
