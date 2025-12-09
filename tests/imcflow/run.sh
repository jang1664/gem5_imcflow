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

DFLAGS="ImcflowPIO,AddrRanges"
export PYTHONPATH=$PYTHONPATH:/root/project/tvm/tvm_practice/tvm_env/lib/python3.10/site-packages

if [ "$GDB" == "yes" ]; then
    $GEM5_HOME/build/X86/gem5.opt --debug-flags=$DFLAGS $GEM5_HOME/configs/imcflow/run_imcflow.py --binary binaries/$BINARY --test-name $TEST_NAME --gdb
else
    $GEM5_HOME/build/X86/gem5.opt --debug-flags=$DFLAGS $GEM5_HOME/configs/imcflow/run_imcflow.py --binary binaries/$BINARY --test-name $TEST_NAME
fi
