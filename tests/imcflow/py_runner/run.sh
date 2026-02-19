#!/bin/bash
# Usage: ./run.sh <binary_name> <gdb_mode> [test_name] [log_dir] [imc_size] [extra_args...]
# Examples:
#   ./run.sh tvm_host_runner no one_conv
#   ./run.sh tvm_host_runner yes resnet8
#   ./run.sh tvm_host_runner no one_conv /path/to/logs 266368
#   ./run.sh tvm_host_runner no one_conv /path/to/logs 266368 --region 0

BINARY=${1:-"test_imcflow"}
GDB=${2:-"no"}
TEST_NAME=${3:-"default_test"}
LOG_DIR=${4:-"./logs"}
IMC_SIZE=${5:-"266368"}

# Capture extra arguments (arguments 6 onwards) to pass to the binary
EXTRA_ARGS="${@:6}"

# Create per-test directories for isolation (enables concurrent execution)
BINARY_DIR="binaries/${TEST_NAME}"
MLF_DIR="mlf_${TEST_NAME}"
mkdir -p "$BINARY_DIR"

# Copy binaries from test-specific host_binary_make directory
TVM_BUILD_DIR=~/project/tvm/tvm_practice/test_imcflow/codegen/${TEST_NAME}/host_binary_make/build
cp $TVM_BUILD_DIR/$BINARY "$BINARY_DIR/"
rm -rf "$MLF_DIR"
mkdir -p "$(dirname "$MLF_DIR")"
cp -r $TVM_BUILD_DIR/mlf "$MLF_DIR"
echo "MLF copied to $MLF_DIR/"

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

# Build extra args option if provided
EXTRA_ARGS_OPT=""
if [ -n "$EXTRA_ARGS" ]; then
    EXTRA_ARGS_OPT="--extra-args \"$EXTRA_ARGS\""
    echo "Extra arguments for binary: $EXTRA_ARGS"
fi

if [ "$GDB" == "yes" ]; then
    eval $GEM5_BIN --outdir="$LOG_DIR" --debug-flags=$DFLAGS $GEM5_HOME/configs/imcflow/run_imcflow.py --binary $BINARY_DIR/$BINARY --test-name $TEST_NAME --runner-name py_runner --imc-size $IMC_SIZE --mlf-dir $MLF_DIR --gdb $EXTRA_ARGS_OPT
else
    # Run without debug flags for faster execution
    eval $GEM5_BIN --outdir="$LOG_DIR" $GEM5_HOME/configs/imcflow/run_imcflow.py --binary $BINARY_DIR/$BINARY --test-name $TEST_NAME --runner-name py_runner --imc-size $IMC_SIZE --mlf-dir $MLF_DIR $EXTRA_ARGS_OPT
fi
