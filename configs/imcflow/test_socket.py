#!/usr/bin/env python3
"""
Test script for gem5 with socket-based ImcflowPIO device
This script creates a simple system with the ImcflowPIO device
"""

import m5
from m5.objects import *

# Create a simple system
system = System()
system.clk_domain = SrcClockDomain()
system.clk_domain.clock = "1GHz"
system.clk_domain.voltage_domain = VoltageDomain()

system.mem_mode = "timing"
system.mem_ranges = [AddrRange("512MB")]

# Create memory bus
system.membus = SystemXBar()

# Simple CPU
system.cpu = X86TimingSimpleCPU()
system.cpu.icache_port = system.membus.cpu_side_ports
system.cpu.dcache_port = system.membus.cpu_side_ports

# Interrupts
system.cpu.createInterruptController()
system.cpu.interrupts[0].pio = system.membus.mem_side_ports
system.cpu.interrupts[0].int_requestor = system.membus.cpu_side_ports
system.cpu.interrupts[0].int_responder = system.membus.mem_side_ports

# Memory controller
system.mem_ctrl = MemCtrl()
system.mem_ctrl.dram = DDR3_1600_8x8()
system.mem_ctrl.dram.range = system.mem_ranges[0]
system.mem_ctrl.port = system.membus.mem_side_ports

# System port
system.system_port = system.membus.cpu_side_ports

# ImcflowPIO device - socket-based connection to VCS
system.imc = ImcflowPIO(
    pio_addr=0x80000000, pio_size=0x10000, vcs_host="127.0.0.1", vcs_port=9999
)
system.imc.pio = system.membus.mem_side_ports

# Create a simple test process
binary = "/bin/ls"  # Simple binary for testing
process = Process(cmd=[binary])
system.cpu.workload = process
system.cpu.createThreads()

# Set up root
root = Root(full_system=False, system=system)
m5.instantiate()

print("=" * 60)
print("gem5 ImcflowPIO Socket Integration Test")
print("=" * 60)
print(f"VCS Server: {system.imc.vcs_host}:{system.imc.vcs_port}")
print(f"ImcflowPIO Address: 0x{system.imc.pio_addr:x}")
print(f"ImcflowPIO Size: 0x{system.imc.pio_size:x}")
print("=" * 60)
print("\nStarting simulation...")
print("NOTE: Make sure VCS simulation is running on port 9999!")
print("=" * 60)

# Run simulation
exit_event = m5.simulate()

print(f"\nSimulation ended: {exit_event.getCause()}")
