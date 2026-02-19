#!/usr/bin/env python3
"""
gem5 + VCS RTL Co-Simulation Runner
Runs TVM workloads on gem5 with ImcFlow RTL simulation via socket communication
"""

import argparse
import os
import sys

import m5
from m5.objects import *

# Parse command-line arguments
parser = argparse.ArgumentParser(
    description="gem5 + VCS RTL co-simulation runner"
)
parser.add_argument(
    "--binary", required=True, help="Path to user-level binary to execute"
)
parser.add_argument(
    "--test-name",
    default="default_test",
    help="Test name for input/output directories",
)
parser.add_argument(
    "--runner-name",
    default="",
    help="Runner name (e.g., py_runner, rtl_runner) for output subdirectory",
)
parser.add_argument(
    "--imc-base",
    type=lambda x: int(x, 0),
    default=0x80000000,
    help="ImcFlow MMIO base address (default: 0x80000000)",
)
parser.add_argument(
    "--imc-size",
    type=lambda x: int(x, 0),
    default=266368,
    help="ImcFlow MMIO region size (default: 266368 = 260KB)",
)
parser.add_argument(
    "--vcs-host",
    default="127.0.0.1",
    help="VCS server host address (default: 127.0.0.1)",
)
parser.add_argument(
    "--vcs-port",
    type=int,
    default=9999,
    help="VCS server port number (default: 9999)",
)
parser.add_argument(
    "--mem-size", default="512MB", help="System memory size (default: 512MB)"
)
parser.add_argument(
    "--gdb",
    action="store_true",
    help="Enable GDB remote debugging on port 7000",
)
parser.add_argument(
    "--mlf-dir",
    default="mlf",
    help="Path to MLF directory (default: mlf)",
)
parser.add_argument(
    "--extra-args",
    default="",
    help="Extra arguments to pass to the binary (e.g., '--region 0')",
)
args = parser.parse_args()

# Dump parsed arguments
print("=" * 70)
print(" gem5 RTL Co-Simulation Configuration")
print("=" * 70)
for arg, value in vars(args).items():
    if "base" in arg or "size" in arg and isinstance(value, int):
        print(f"  {arg}: {value} (0x{value:x})")
    else:
        print(f"  {arg}: {value}")
print("=" * 70)
print()

# Create system
system = System()
system.clk_domain = SrcClockDomain()
system.clk_domain.clock = "1GHz"
system.clk_domain.voltage_domain = VoltageDomain()

system.mem_mode = "timing"
system.mem_ranges = [AddrRange(args.mem_size)]
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

# ImcflowPIOSocket device for VCS RTL co-simulation
system.imc = ImcflowPIOSocket(
    pio_addr=args.imc_base,
    pio_size=args.imc_size,
    vcs_host=args.vcs_host,
    vcs_port=args.vcs_port,
)
system.imc.pio = system.membus.mem_side_ports

# Check if binary exists
if not os.path.exists(args.binary):
    print(f"[ERROR] Binary not found: {args.binary}")
    sys.exit(1)

# Set up workload
system.workload = SEWorkload.init_compatible(args.binary)

# Enable GDB if requested
if args.gdb:
    system.workload.wait_for_remote_gdb = True
    system.workload.remote_gdb_port = 7000
    print(f"[*] GDB remote debugging enabled on port 7000")

# Build command for binary
# Args: <test_name> [eval_dir] [graph.json] [params.params] [runner_name] [extra_args...]
binary_cmd = [args.binary, args.test_name]
if args.runner_name:
    # Pass default eval_dir, graph, params, then runner_name
    # Use --mlf-dir for test-specific MLF directory (enables concurrent execution)
    # test_name already includes "eval_dir/" prefix (e.g., "eval_dir/xxx_evl")
    eval_dir = "/root/project/tvm/tvm_practice/test_imcflow/codegen"
    graph_path = f"{args.mlf_dir}/executor-config/graph/default.graph"
    params_path = f"{args.mlf_dir}/parameters/default.params"
    binary_cmd.extend([eval_dir, graph_path, params_path, args.runner_name])

# Append extra arguments if provided (e.g., --region 0)
if args.extra_args:
    extra_args_list = args.extra_args.split()
    binary_cmd.extend(extra_args_list)

process = Process(cmd=binary_cmd)
system.cpu.workload = process
system.cpu.createThreads()

root = Root(full_system=False, system=system)

# Print configuration
print("=" * 70)
print(" gem5 + VCS RTL Co-Simulation")
print("=" * 70)
print(f" Device:            ImcflowPIOSocket")
print(f" MMIO Base:         0x{args.imc_base:08x}")
print(f" MMIO Size:         0x{args.imc_size:x} ({args.imc_size//1024}KB)")
print(f" VCS Server:        {args.vcs_host}:{args.vcs_port}")
print(f" Memory Size:       {args.mem_size}")
print(f" Binary:            {os.path.basename(args.binary)}")
print(f" Test Name:         {args.test_name}")
print("=" * 70)
print()

m5.instantiate()

# CRITICAL: Map MMIO region into process address space for SE mode
print(
    f"[*] Mapping MMIO region 0x{args.imc_base:08x}-0x{args.imc_base+args.imc_size:08x} into process..."
)
process.map(args.imc_base, args.imc_base, args.imc_size)
print("[*] MMIO mapping complete!")
print()

print("[*] Starting simulation...")
print()
exit_event = m5.simulate()
print()
print(f"[*] Simulation complete: {exit_event.getCause()}")
