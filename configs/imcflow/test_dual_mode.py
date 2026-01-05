#!/usr/bin/env python3
"""
Test configuration showing BOTH modes:
- ImcflowPIO: Python simulator mode (pybind11)
- ImcflowPIOSocket: VCS co-simulation mode (socket)

This demonstrates that both can coexist in the same gem5 build.
"""

import os

import m5
from m5.objects import *

# Create system
system = System()
system.clk_domain = SrcClockDomain()
system.clk_domain.clock = "1GHz"
system.clk_domain.voltage_domain = VoltageDomain()

system.mem_mode = "timing"
system.mem_ranges = [AddrRange("512MB")]
system.membus = SystemXBar()

# CPU
system.cpu = X86TimingSimpleCPU()
system.cpu.icache_port = system.membus.cpu_side_ports
system.cpu.dcache_port = system.membus.cpu_side_ports

# Interrupts
system.cpu.createInterruptController()
system.cpu.interrupts[0].pio = system.membus.mem_side_ports
system.cpu.interrupts[0].int_requestor = system.membus.cpu_side_ports
system.cpu.interrupts[0].int_responder = system.membus.mem_side_ports

# Memory
system.mem_ctrl = MemCtrl()
system.mem_ctrl.dram = DDR3_1600_8x8()
system.mem_ctrl.dram.range = system.mem_ranges[0]
system.mem_ctrl.port = system.membus.mem_side_ports
system.system_port = system.membus.cpu_side_ports

# OPTION 1: Python simulator mode (original pybind11)
# Uncomment this to use Python simulator:
# system.imc = ImcflowPIO(
#     pio_addr=0x80000000,
#     pio_size=0x10000
# )
# system.imc.pio = system.membus.mem_side_ports

# OPTION 2: VCS co-simulation mode (socket-based)
# This is the default for this test
system.imc = ImcflowPIOSocket(
    pio_addr=0x80000000, pio_size=0x10000, vcs_host="127.0.0.1", vcs_port=9999
)
system.imc.pio = system.membus.mem_side_ports

# Test binary
test_binary = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "../../tests/test-progs/hello/bin/x86/linux/hello",
)

if not os.path.exists(test_binary):
    print(f"[ERROR] Test binary not found: {test_binary}")
    import sys

    sys.exit(1)

system.workload = SEWorkload.init_compatible(test_binary)
process = Process(cmd=[test_binary])
system.cpu.workload = process
system.cpu.createThreads()

root = Root(full_system=False, system=system)

print("=" * 70)
print(" gem5 Dual-Mode Test Configuration")
print("=" * 70)
print(f" Device Type:       {system.imc.type}")
if hasattr(system.imc, "vcs_host"):
    print(f" Mode:              VCS Socket Co-simulation")
    print(f" VCS Server:        {system.imc.vcs_host}:{system.imc.vcs_port}")
else:
    print(f" Mode:              Python Simulator (pybind11)")
print(f" Device Base:       0x{system.imc.pio_addr:08x}")
print(f" Device Size:       0x{system.imc.pio_size:08x}")
print("=" * 70)

m5.instantiate()

print("\n[*] Starting simulation...")
exit_event = m5.simulate()

print(f"\n[*] Simulation ended: {exit_event.getCause()}")
