#!/bin/bash
# RTL Runner for TVM Workloads
# Usage: ./run.sh <binary_name> <gdb_mode> [test_name]
# Examples:
#   ./run.sh tvm_host_runner no one_conv
#   ./run.sh tvm_host_runner yes resnet8

set -e  # Exit on error

# Directory structure
BUILD_DIR="build"
LOGS_DIR="logs"
TVM_BUILD_DIR=~/project/tvm/tvm_practice/test_imcflow/codegen/host_binary_make/build

BINARY=${1:-"tvm_host_runner"}
GDB=${2:-"no"}
TEST_NAME=${3:-"default_test"}

echo "========================================"
echo "  RTL Runner - TVM Workload Execution"
echo "========================================"
echo "Binary:     $BINARY"
echo "GDB Mode:   $GDB"
echo "Test Name:  $TEST_NAME"
echo ""

# Create directories
echo "Setting up directories..."
mkdir -p binaries
mkdir -p $LOGS_DIR
mkdir -p test_outputs/$TEST_NAME
echo ""

# Copy TVM binaries and MLF
echo "Copying TVM binaries and model files..."
if [ ! -f "$TVM_BUILD_DIR/$BINARY" ]; then
    echo "ERROR: Binary not found at $TVM_BUILD_DIR/$BINARY"
    echo "Please compile the TVM host runner first"
    exit 1
fi

cp $TVM_BUILD_DIR/$BINARY binaries/
echo "  ✓ Copied $BINARY to binaries/"

if [ -d "$TVM_BUILD_DIR/mlf" ]; then
    cp -r $TVM_BUILD_DIR/mlf .
    echo "  ✓ Copied MLF (Model Library Format) directory"
else
    echo "  ! Warning: MLF directory not found at $TVM_BUILD_DIR/mlf"
fi

# Copy test inputs if they exist
if [ -d "$TVM_BUILD_DIR/test_inputs/$TEST_NAME" ]; then
    mkdir -p test_inputs
    cp -r $TVM_BUILD_DIR/test_inputs/$TEST_NAME test_inputs/
    echo "  ✓ Copied test inputs for $TEST_NAME"
fi
echo ""

# Select gem5 binary: prefer gem5.fast if available, otherwise use gem5.opt
if [ -f "$GEM5_HOME/build/X86/gem5.fast" ]; then
    GEM5_BIN="$GEM5_HOME/build/X86/gem5.fast"
    echo "Using gem5.fast for faster simulation"
else
    GEM5_BIN="$GEM5_HOME/build/X86/gem5.opt"
    echo "Using gem5.opt (gem5.fast not found)"
fi
echo ""

# Compile RTL simulation if needed
if [ ! -f "$BUILD_DIR/simv_imcflow_gem5" ]; then
    echo "=== Compiling RTL simulation with VCS ==="
    make compile
    if [ $? -ne 0 ]; then
        echo "ERROR: VCS compilation failed"
        exit 1
    fi
    echo "Compilation successful!"
    echo ""
fi

# Clean up any old log files
rm -f $LOGS_DIR/vcs_sim.log $LOGS_DIR/gem5_output.log

# Start VCS simulation in background
echo "=== Starting VCS RTL simulation ==="
echo "VCS listening on port 9999..."
echo "VCS log: $LOGS_DIR/vcs_sim.log"
echo "Waveform: imcflow_gem5.fsdb"
$BUILD_DIR/simv_imcflow_gem5 +fsdbfile+imcflow_gem5.fsdb +fsdb+autoflush > $LOGS_DIR/vcs_sim.log 2>&1 &
VCS_PID=$!
echo "VCS simulation started with PID: $VCS_PID"
echo ""

# Wait for VCS to initialize and start listening on port
echo "Waiting for VCS to initialize (5 seconds)..."
sleep 5

# Check if VCS is still running
if ! kill -0 $VCS_PID 2>/dev/null; then
    echo "ERROR: VCS simulation terminated unexpectedly"
    echo ""
    echo "Last 30 lines of VCS log:"
    tail -30 $LOGS_DIR/vcs_sim.log
    exit 1
fi

echo "VCS simulation is running, ready for gem5 connection"
echo ""

# Run gem5 with ImcflowPIOSocket device
echo "=== Starting gem5 with TVM workload ==="
echo "Running: $GEM5_BIN with run_imcflow_rtl.py"
echo "gem5 log: $LOGS_DIR/gem5_output.log"
echo ""

# Build gem5 command
GEM5_CMD="$GEM5_BIN $GEM5_HOME/configs/imcflow/run_imcflow_rtl.py \
    --binary binaries/$BINARY \
    --test-name $TEST_NAME \
    --runner-name rtl_runner"

# Add GDB flag if requested
if [ "$GDB" == "yes" ]; then
    GEM5_CMD="$GEM5_CMD --gdb"
    echo "[*] GDB debugging enabled on port 7000"
fi

# Run gem5 and save output
$GEM5_CMD 2>&1 | tee $LOGS_DIR/gem5_output.log

GEM5_EXIT=${PIPESTATUS[0]}

# Wait a moment for VCS to finish processing
echo ""
echo "Waiting for VCS to complete..."
sleep 2

# Stop VCS if still running
if kill -0 $VCS_PID 2>/dev/null; then
    echo "Sending termination signal to VCS..."
    kill $VCS_PID 2>/dev/null || true
    sleep 1
    # Force kill if needed
    kill -9 $VCS_PID 2>/dev/null || true
fi

wait $VCS_PID 2>/dev/null || VCS_EXIT=$?

echo ""
echo "========================================"
echo "  Co-Simulation Complete"
echo "========================================"
echo "gem5 exit code: $GEM5_EXIT"
echo ""

# Display VCS simulation summary
echo "=== VCS Simulation Log (last 40 lines) ==="
tail -40 $LOGS_DIR/vcs_sim.log
echo ""

# Check for success
if [ $GEM5_EXIT -eq 0 ]; then
    echo "========================================"
    echo "  ✓ SIMULATION COMPLETED SUCCESSFULLY"
    echo "========================================"
    echo ""
    echo "Output files:"
    if [ -d "test_outputs/$TEST_NAME" ]; then
        echo "  - Test outputs: test_outputs/$TEST_NAME/"
        ls -lh test_outputs/$TEST_NAME/ 2>/dev/null | tail -n +2 | awk '{print "      " $9 " (" $5 ")"}'
    fi
    echo ""
    echo "Logs saved:"
    echo "  - VCS log: $LOGS_DIR/vcs_sim.log"
    echo "  - gem5 log: $LOGS_DIR/gem5_output.log"
    echo "  - gem5 m5out: m5out/"
    echo ""
    echo "Build artifacts:"
    echo "  - VCS binary: $BUILD_DIR/simv_imcflow_gem5"
    echo "  - Waveform: imcflow_gem5.fsdb (if generated)"
    exit 0
else
    echo "========================================"
    echo "  ✗ SIMULATION FAILED"
    echo "========================================"
    echo ""
    echo "Check logs for details:"
    echo "  - VCS log: $LOGS_DIR/vcs_sim.log"
    echo "  - gem5 log: $LOGS_DIR/gem5_output.log"
    exit 1
fi
