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
    "--mlf-dir",
    default="mlf",
    help="Path to MLF directory (default: mlf)",
)
parser.add_argument(
    "--extra-args",
    default="",
    help="Extra arguments to pass to the binary (e.g., '--region 0')",
)
parser.add_argument(
    "--noise-csv",
    default=None,
    help="Path to ADC noise probability CSV. Exported as IMCFLOW_NOISE_CSV "
    "before the bridge imports Imcflow, so IMCU picks it up at construction.",
)
parser.add_argument(
    "--noise-layout-json",
    default=None,
    help="Path to imce_map noise layout JSON (concat_per_core.json). Exported "
    "as IMCFLOW_NOISE_LAYOUT_JSON so each IMCU picks the right pseudo-channel "
    "slice. CSV must have n_cores*n_per_core channels matching the layout.",
)
parser.add_argument(
    "--noise-mode",
    choices=["sample", "greedy"],
    default=None,
    help="ADC noise sampling mode. 'sample' (default): empirical inverse-CDF; "
    "'greedy': deterministic argmax over diff_bin. Exported as IMCFLOW_NOISE_MODE.",
)
args = parser.parse_args()

# Export noise CSV path into the env so imcflow_sim.imcflow.bridge (loaded
# lazily on first MMIO transaction) sees it via os.environ in IMCU.__init__.
if args.noise_csv is not None:
    os.environ["IMCFLOW_NOISE_CSV"] = args.noise_csv
if args.noise_layout_json is not None:
    os.environ["IMCFLOW_NOISE_LAYOUT_JSON"] = args.noise_layout_json
if args.noise_mode is not None:
    os.environ["IMCFLOW_NOISE_MODE"] = args.noise_mode

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

instantiate()
process.map(args.imc_base, args.imc_base, args.imc_size)

exit_event = simulate()
print(f"Exiting @ tick {exit_event.getCause()} : {exit_event.getCause()}")
