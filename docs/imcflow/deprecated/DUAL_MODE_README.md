# gem5 Dual-Mode Support: Python and VCS Co-simulation

The imcflow device now supports **two modes** that can coexist in the same gem5 build:

## 1. Python Simulator Mode (Original)
- **Device**: `ImcflowPIO`
- **Backend**: Python simulator via pybind11
- **Use case**: Pure software simulation, debugging, development

```python
from m5.objects import ImcflowPIO

system.imc = ImcflowPIO(
    pio_addr=0x80000000,
    pio_size=0x10000
)
system.imc.pio = system.membus.mem_side_ports
```

**Requirements**:
- Python imcflow_sim package in PYTHONPATH
- pybind11 dependencies

## 2. VCS Co-simulation Mode (New)
- **Device**: `ImcflowPIOSocket`
- **Backend**: VCS via TCP sockets and DPI-C
- **Use case**: RTL simulation, hardware verification

```python
from m5.objects import ImcflowPIOSocket

system.imc = ImcflowPIOSocket(
    pio_addr=0x80000000,
    pio_size=0x10000,
    vcs_host="127.0.0.1",
    vcs_port=9999
)
system.imc.pio = system.membus.mem_side_ports
```

**Requirements**:
- VCS simulation running on specified port
- DPI-C socket server (see `dpi_example/socket_test/`)

## Building

Both devices are built automatically:

```bash
cd /root/project/imcflow/pmap/ISA_sim/gem5
scons build/X86/gem5.opt -j$(nproc)
```

## Testing

### Python Mode
```bash
# Ensure Python simulator is in path
export PYTHONPATH=/path/to/imcflow_sim:$PYTHONPATH

# Run with ImcflowPIO
./build/X86/gem5.opt configs/imcflow/run_imcflow.py \
  --binary tests/test-progs/hello/bin/x86/linux/hello
```

### VCS Socket Mode

Terminal 1 - Start VCS:
```bash
cd dpi_example/socket_test
./simv_socket
```

Terminal 2 - Run gem5:
```bash
cd /root/project/imcflow/pmap/ISA_sim/gem5
./build/X86/gem5.opt configs/imcflow/test_socket_simple.py
```

Or use automated test:
```bash
bash test_integration.sh
```

## Choosing Between Modes

| Feature | Python Mode | VCS Socket Mode |
|---------|-------------|-----------------|
| Speed | Fast | Slower (RTL) |
| Accuracy | Functional | Cycle-accurate |
| Setup | Easy | Requires VCS |
| Debugging | Python tools | VCS + Waveforms |
| Use Case | Software dev | Hardware verification |

## Implementation Details

### Files
- **Python Mode**:
  - `imcflow_pio.cc` - pybind11 implementation
  - `imcflow_pio.hh` - Header
  - `ImcflowPIO.py` - SimObject

- **VCS Socket Mode**:
  - `imcflow_pio_socket.cc` - Socket implementation
  - `imcflow_pio_socket.hh` - Header
  - `ImcflowPIOSocket.py` - SimObject

### Debug Flags
- `--debug-flags=ImcflowPIO` - Python mode debug
- `--debug-flags=ImcflowPIOSocket` - VCS socket mode debug

## Migration Guide

### From Python to VCS Socket

Change:
```python
system.imc = ImcflowPIO(pio_addr=0x80000000, pio_size=0x10000)
```

To:
```python
system.imc = ImcflowPIOSocket(
    pio_addr=0x80000000,
    pio_size=0x10000,
    vcs_host="127.0.0.1",
    vcs_port=9999
)
```

That's it! The interface is identical except for the constructor.

## Example Configurations

See:
- `configs/imcflow/run_imcflow.py` - Python mode example
- `configs/imcflow/test_socket_simple.py` - VCS socket mode example
- `configs/imcflow/test_dual_mode.py` - Shows both modes (switch via comment)
