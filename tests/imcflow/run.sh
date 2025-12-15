#!/bin/bash
# Usage: ./run.sh <binary_name> <gdb_mode> [test_name]
# Examples:
#   ./run.sh tvm_host_runner no one_conv
#   ./run.sh tvm_host_runner yes resnet8

BINARY=${1:-"test_imcflow"}
GDB=${2:-"no"}
TEST_NAME=${3:-"default_test"}

cp ~/project/tvm/tvm_practice/test_imcflow/codegen/host_binary_make/build/tvm_host_runner binaries/
cp -r ~/project/tvm/tvm_practice/test_imcflow/codegen/host_binary_make/build/mlf .

# Create output directory
mkdir -p test_outputs/$TEST_NAME

# DFLAGS="ImcflowPIO,BaseXBar,AddrRanges"

# Debug flags enabled only for GDB mode (for performance)
DFLAGS="ImcflowPIO,AddrRanges"
export PYTHONPATH=$PYTHONPATH:/root/project/tvm/tvm_practice/tvm_env/lib/python3.10/site-packages

# Select gem5 binary: prefer gem5.fast if available, otherwise use gem5.opt
if [ -f "$GEM5_HOME/build/X86/gem5.fast" ]; then
    GEM5_BIN="$GEM5_HOME/build/X86/gem5.fast"
    echo "Using gem5.fast for faster simulation"
else
    GEM5_BIN="$GEM5_HOME/build/X86/gem5.opt"
    echo "Using gem5.opt (gem5.fast not found)"
fi

if [ "$GDB" == "yes" ]; then
    $GEM5_BIN --debug-flags=$DFLAGS $GEM5_HOME/configs/imcflow/run_imcflow.py --binary binaries/$BINARY --test-name $TEST_NAME --gdb
else
    # Run without debug flags for faster execution
    $GEM5_BIN $GEM5_HOME/configs/imcflow/run_imcflow.py --binary binaries/$BINARY --test-name $TEST_NAME
fi
