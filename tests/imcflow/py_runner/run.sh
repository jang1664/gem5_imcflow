#!/bin/bash
# Usage: ./run.sh <binary_name> <gdb_mode> [test_name] [log_dir] [npz_file]
# Examples:
#   ./run.sh tvm_host_runner no one_conv
#   ./run.sh tvm_host_runner yes resnet8
#   ./run.sh tvm_host_runner no one_conv /path/to/logs

BINARY=${1:-"test_imcflow"}
GDB=${2:-"no"}
TEST_NAME=${3:-"default_test"}
LOG_DIR=${4:-"./logs"}
NPZ_FILE=${5:-""}

# Create binaries directory if it doesn't exist
mkdir -p binaries

# Copy binaries from test-specific host_binary_make directory
TVM_BUILD_DIR=~/project/tvm/tvm_practice/test_imcflow/codegen/${TEST_NAME}/host_binary_make/build
cp $TVM_BUILD_DIR/tvm_host_runner binaries/
cp -r $TVM_BUILD_DIR/mlf .

# Copy NPZ file if provided
if [ -n "$NPZ_FILE" ]; then
    if [ -f "$NPZ_FILE" ]; then
        cp "$NPZ_FILE" binaries/
        NPZ_FILENAME=$(basename "$NPZ_FILE")
        # Pass full path within sim directory since binary runs from there
        NPZ_FILE_ARG="binaries/$NPZ_FILENAME"
        echo "Copied NPZ file: $NPZ_FILE -> $NPZ_FILE_ARG"
    else
        echo "Warning: NPZ file not found: $NPZ_FILE"
        NPZ_FILE_ARG=""
    fi
else
    NPZ_FILE_ARG=""
fi

# Create output directory
mkdir -p test_outputs/$TEST_NAME

# Create log directory
mkdir -p "$LOG_DIR"

# DFLAGS="ImcflowPIO,BaseXBar,AddrRanges"

# Debug flags enabled only for GDB mode (for performance)
DFLAGS="ImcflowPIO,AddrRanges"
export PYTHONPATH=$PYTHONPATH:/root/project/tvm/tvm_practice/tvm_env/lib/python3.10/site-packages

# Set imcflow log directory to redirect simulator logs
export IMCFLOW_LOG_DIR="$LOG_DIR"

# Select gem5 binary: prefer gem5.fast if available, otherwise use gem5.opt
if [ -f "$GEM5_HOME/build/X86/gem5.fast" ]; then
    GEM5_BIN="$GEM5_HOME/build/X86/gem5.fast"
    echo "Using gem5.fast for faster simulation"
else
    GEM5_BIN="$GEM5_HOME/build/X86/gem5.opt"
    echo "Using gem5.opt (gem5.fast not found)"
fi

if [ "$GDB" == "yes" ]; then
    $GEM5_BIN --outdir="$LOG_DIR" --debug-flags=$DFLAGS $GEM5_HOME/configs/imcflow/run_imcflow.py --binary binaries/$BINARY --test-name $TEST_NAME --runner-name py_runner --gdb ${NPZ_FILE_ARG:+--npz-file "$NPZ_FILE_ARG"}
else
    # Run without debug flags for faster execution
    $GEM5_BIN --outdir="$LOG_DIR" $GEM5_HOME/configs/imcflow/run_imcflow.py --binary binaries/$BINARY --test-name $TEST_NAME --runner-name py_runner ${NPZ_FILE_ARG:+--npz-file "$NPZ_FILE_ARG"}
fi
