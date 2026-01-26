# Example run script for gem5 using the ImcflowPIO device
# Usage:
#   build/X86/gem5.opt pmap/ISA_sim/gem5/config/imcflow/run_imcflow.py \
#     --binary tests/test-progs/hello/bin/x86/linux/hello

import argparse
import os
import sys

from m5 import (
    instantiate,
    options,
    simulate,
)
from m5.objects import (
    Process,
    Root,
    SEWorkload,
)

# Add the config directory to the path so we can import system_imcflow
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from system_imcflow import make_system

parser = argparse.ArgumentParser()
parser.add_argument(
    "--binary", required=True, help="Path to user-level binary"
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
parser.add_argument("--imc-base", type=lambda x: int(x, 0), default=0x80000000)
parser.add_argument("--imc-size", type=lambda x: int(x, 0), default=266368)
parser.add_argument("--mem-size", default="512MB")
parser.add_argument(
    "--gdb",
    action="store_true",
    help="Enable gdb stub on the CPU",
)
parser.add_argument(
    "--npz-file",
    default="",
    help="NPZ file path to pass to the binary",
)
args = parser.parse_args()

# Dump parsed arguments
print("=" * 70)
print(" gem5 Configuration")
print("=" * 70)
for arg, value in vars(args).items():
    if "base" in arg or "size" in arg and isinstance(value, int):
        print(f"  {arg}: {value} (0x{value:x})")
    else:
        print(f"  {arg}: {value}")
print("=" * 70)
print()

system = make_system(args.imc_base, args.imc_size, args.mem_size)

# User-level workload
system.workload = SEWorkload.init_compatible(args.binary)
if args.gdb:
    system.workload.wait_for_remote_gdb = True
    system.workload.remote_gdb_port = 7000

# Build command for binary
# Args: <test_name> [eval_dir] [graph.json] [params.params] [runner_name] [npz_file]
binary_cmd = [args.binary, args.test_name]
if args.runner_name:
    # Pass default eval_dir, graph, params, then runner_name
    eval_dir = "/root/project/tvm/tvm_practice/test_imcflow/codegen"
    graph_path = "mlf/executor-config/graph/default.graph"
    params_path = "mlf/parameters/default.params"
    binary_cmd.extend([eval_dir, graph_path, params_path, args.runner_name])

# Add NPZ file if specified
if args.npz_file:
    binary_cmd.append(args.npz_file)

process = Process(cmd=binary_cmd)
system.cpu.workload = process
system.cpu.createThreads()

root = Root(full_system=False, system=system)

instantiate()
process.map(args.imc_base, args.imc_base, args.imc_size)

exit_event = simulate()
print(f"Exiting @ tick {exit_event.getCause()} : {exit_event.getCause()}")
