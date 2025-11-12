#!/bin/bash

BINARY=${1:-"test_imcflow"}
GDB=${2:-"no"}
# DFLAGS="ImcflowPIO,BaseXBar,AddrRanges"

DFLAGS="ImcflowPIO,AddrRanges"
export PYTHONPATH=$PYTHONPATH:/root/project/tvm/tvm_practice/tvm_env/lib/python3.10/site-packages

if [ "$GDB" == "yes" ]; then
    $GEM5_HOME/build/X86/gem5.opt --debug-flags=$DFLAGS $GEM5_HOME/configs/imcflow/run_imcflow.py --binary binaries/$BINARY --gdb
else
    $GEM5_HOME/build/X86/gem5.opt --debug-flags=$DFLAGS $GEM5_HOME/configs/imcflow/run_imcflow.py --binary binaries/$BINARY
fi