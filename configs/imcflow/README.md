# gem5 config for imcflow PIO integration

This package provides a minimal config to attach the `ImcflowPIO` device and run
with a `TimingSimpleCPU`.

Files:
- `system_imcflow.py`: builds a small system and maps the PIO device at `imc_base`.
- `run_imcflow.py`: sample run script for SE mode.

Example run (within gem5 tree after building X86):

```bash
build/X86/gem5.opt /path/to/this/repo/pmap/ISA_sim/gem5/config/imcflow/run_imcflow.py \
  --binary tests/test-progs/hello/bin/x86/linux/hello \
  --imc-base 0x80000000 --imc-size 0x20000
```

The `ImcflowPIO` device forwards MMIO accesses to the Python imcflow model via
`imcflow_sim.imcflow.bridge.get_or_create_forwarder()` which returns a singleton
`MmioForwarder`.

Notes:
- Ensure `PYTHONPATH` includes the path to this repository so gem5 can import
  the `imcflow_sim` Python package.
- If you want the device to also advance the imcflow internal scheduler on each
  write, you can extend the C++ `write()` to call into a Python `step(k)` helper.
