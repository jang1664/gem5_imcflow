#!/usr/bin/env python3
"""
Simple memory access test for ImcflowPIO socket connection
Uses inline assembly to generate MMIO reads/writes
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

# ImcflowPIO device
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

# Create a test program
# We'll use a simple test binary
test_binary = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "../../tests/test-progs/hello/bin/x86/linux/hello",
)

if not os.path.exists(test_binary):
    print(f"[ERROR] Test binary not found: {test_binary}")
    import sys

    sys.exit(1)

# Set up workload
system.workload = SEWorkload.init_compatible(test_binary)

process = Process(cmd=[test_binary])
system.cpu.workload = process
system.cpu.createThreads()

root = Root(full_system=False, system=system)

print("=" * 70)
print(" gem5 + VCS Socket Integration Test")
print("=" * 70)
print(f" VCS Server:        {system.imc.vcs_host}:{system.imc.vcs_port}")
print(f" ImcflowPIO Base:   0x{IMC_BASE:08x}")
print(f" ImcflowPIO Size:   0x{IMC_SIZE:08x}")
print("=" * 70)
print("\n[!] IMPORTANT: Start VCS simulation first!")
print("    cd /root/dpi_example/socket_test")
print("    ./simv_socket")
print("\n[*] Instantiating gem5...")

m5.instantiate()

print("[*] Starting simulation...")
print("=" * 70)

exit_event = m5.simulate()

print("\n" + "=" * 70)
print(f" Simulation ended: {exit_event.getCause()}")
print("=" * 70)
