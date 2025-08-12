# Example run script for gem5 using the ImcflowPIO device
# Usage:
#   build/X86/gem5.opt pmap/ISA_sim/gem5/config/imcflow/run_imcflow.py \
#     --binary tests/test-progs/hello/bin/x86/linux/hello

import argparse

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

from .system_imcflow import make_system


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--binary", required=True, help="Path to user-level binary"
    )
    parser.add_argument(
        "--imc-base", type=lambda x: int(x, 0), default=0x80000000
    )
    parser.add_argument(
        "--imc-size", type=lambda x: int(x, 0), default=0x20000
    )
    parser.add_argument("--mem-size", default="512MB")
    args = parser.parse_args()

    system = make_system(args.imc_base, args.imc_size, args.mem_size)

    # User-level workload
    process = Process(cmd=[args.binary])
    system.cpu.workload = process
    system.cpu.createThreads()

    root = Root(full_system=False, system=system)

    instantiate(root)

    exit_event = simulate()
    print(f"Exiting @ tick {exit_event.getCause()} : {exit_event.getCause()}")


if __name__ == "__main__":
    main()
