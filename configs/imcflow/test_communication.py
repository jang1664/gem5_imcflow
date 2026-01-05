#!/usr/bin/env python3
"""
gem5 ↔ VCS Communication Test
Tests bidirectional data flow with clear terminal output
"""

import os
import sys

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

# ImcflowPIOSocket device for VCS communication
IMC_BASE = 0x80000000
IMC_SIZE = 0x10000
VCS_PORT = 9999

system.imc = ImcflowPIOSocket(
    pio_addr=IMC_BASE,
    pio_size=IMC_SIZE,
    vcs_host="127.0.0.1",
    vcs_port=VCS_PORT,
)
system.imc.pio = system.membus.mem_side_ports

# Test binary - compile the communication test
test_dir = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "../../tests/test-progs/imcflow",
)
test_binary = os.path.join(test_dir, "mmio_communication_test")

# Check if binary exists, if not provide compilation instructions
if not os.path.exists(test_binary):
    print(f"[ERROR] Test binary not found: {test_binary}")
    print(f"\nCompile it with:")
    print(f"  cd {test_dir}")
    print(
        f"  gcc -static -o mmio_communication_test mmio_communication_test.c"
    )
    sys.exit(1)

# Set up workload
system.workload = SEWorkload.init_compatible(test_binary)
process = Process(cmd=[test_binary])
system.cpu.workload = process
system.cpu.createThreads()

root = Root(full_system=False, system=system)

print("=" * 70)
print(" gem5 ↔ VCS Bidirectional Communication Test")
print("=" * 70)
print(f" Device:            ImcflowPIOSocket")
print(f" MMIO Base:         0x{IMC_BASE:08x}")
print(f" MMIO Size:         0x{IMC_SIZE:x} ({IMC_SIZE//1024}KB)")
print(f" VCS Server:        127.0.0.1:{VCS_PORT}")
print(f" Test Program:      {os.path.basename(test_binary)}")
print("=" * 70)
print()

m5.instantiate()

# CRITICAL: Map MMIO region into process address space for SE mode
print(
    f"[*] Mapping MMIO region 0x{IMC_BASE:08x}-0x{IMC_BASE+IMC_SIZE:08x} into process..."
)
process.map(IMC_BASE, IMC_BASE, IMC_SIZE)
print("[*] MMIO mapping complete!")
print()

print("[*] Starting communication test...")
print()
exit_event = m5.simulate()
print()
print(f"[*] Test completed: {exit_event.getCause()}")
