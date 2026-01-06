#!/bin/bash
# RTL Co-Simulation Runner for ImcFlow with gem5
# Usage: ./run.sh <binary_name> <gdb_mode> [test_name]
# Examples:
#   ./run.sh tvm_host_runner no one_conv
#   ./run.sh tvm_host_runner yes resnet8

# Directory structure
BUILD_DIR="build"
LOGS_DIR="logs"

BINARY=${1:-"test_imcflow"}
GDB=${2:-"no"}
TEST_NAME=${3:-"default_test"}

echo "=== ImcFlow RTL Co-Simulation Runner ==="
echo "Binary: $BINARY"
echo "Test Name: $TEST_NAME"
echo "GDB Mode: $GDB"
echo ""

# Create directories
mkdir -p binaries
mkdir -p $LOGS_DIR
mkdir -p test_outputs/$TEST_NAME

# Copy TVM binary
cp ~/project/tvm/tvm_practice/test_imcflow/codegen/host_binary_make/build/tvm_host_runner binaries/
cp -r ~/project/tvm/tvm_practice/test_imcflow/codegen/host_binary_make/build/mlf .

# Set TVM Python path
export PYTHONPATH=$PYTHONPATH:/root/project/tvm/tvm_practice/tvm_env/lib/python3.10/site-packages

# Select gem5 binary: prefer gem5.fast if available, otherwise use gem5.opt
if [ -f "$GEM5_HOME/build/X86/gem5.fast" ]; then
    GEM5_BIN="$GEM5_HOME/build/X86/gem5.fast"
    echo "Using gem5.fast for faster simulation"
else
    GEM5_BIN="$GEM5_HOME/build/X86/gem5.opt"
    echo "Using gem5.opt (gem5.fast not found)"
fi

# Compile RTL simulation if needed
if [ ! -f "$BUILD_DIR/simv_imcflow_gem5" ]; then
    echo ""
    echo "=== Compiling RTL simulation with VCS ==="
    make compile
    if [ $? -ne 0 ]; then
        echo "ERROR: VCS compilation failed"
        exit 1
    fi
    echo "Compilation successful!"
fi

# Start VCS simulation in background
echo ""
echo "=== Starting VCS RTL simulation (waiting on port 9999) ==="
echo "VCS log: $LOGS_DIR/vcs_sim.log"
$BUILD_DIR/simv_imcflow_gem5 > $LOGS_DIR/vcs_sim.log 2>&1 &
VCS_PID=$!
echo "VCS simulation started with PID: $VCS_PID"

# Wait for VCS to initialize and start listening
echo "Waiting for VCS to initialize (5 seconds)..."
sleep 5

# Check if VCS is still running
if ! kill -0 $VCS_PID 2>/dev/null; then
    echo "ERROR: VCS simulation terminated unexpectedly"
    echo "Last 20 lines of VCS log:"
    tail -20 $LOGS_DIR/vcs_sim.log
    exit 1
fi

echo "VCS simulation is running, ready for gem5 connection"

# Run gem5 with ImcflowPIOSocket device
echo ""
echo "=== Starting gem5 with ImcflowPIOSocket device ==="

DFLAGS="ImcflowPIOSocket,AddrRanges"

if [ "$GDB" == "yes" ]; then
    echo "Running gem5 with GDB support and debug flags..."
    $GEM5_BIN --debug-flags=$DFLAGS $GEM5_HOME/configs/imcflow/run_imcflow_socket.py --binary binaries/$BINARY --test-name $TEST_NAME --gdb
else
    echo "Running gem5 in normal mode..."
    $GEM5_BIN $GEM5_HOME/configs/imcflow/run_imcflow_socket.py --binary binaries/$BINARY --test-name $TEST_NAME
fi

GEM5_EXIT=$?

# Wait for VCS simulation to complete
echo ""
echo "=== Waiting for VCS simulation to finish ==="
wait $VCS_PID
VCS_EXIT=$?

echo ""
echo "=== Co-Simulation Complete ==="
echo "gem5 exit code: $GEM5_EXIT"
echo "VCS exit code: $VCS_EXIT"
echo ""
echo "Logs:"
echo "  VCS simulation: $LOGS_DIR/vcs_sim.log"
echo "  gem5 output: m5out/terminal (or in current terminal)"
echo ""
echo "Build artifacts:"
echo "  VCS binary: $BUILD_DIR/simv_imcflow_gem5"
echo "  Build files: $BUILD_DIR/"
echo ""

# Display last part of VCS log for summary
echo "=== VCS Simulation Summary (last 30 lines) ==="
tail -30 $LOGS_DIR/vcs_sim.log

if [ $GEM5_EXIT -eq 0 ] && [ $VCS_EXIT -eq 0 ]; then
    echo ""
    echo "SUCCESS: Co-simulation completed successfully!"
    exit 0
else
    echo ""
    echo "ERROR: Co-simulation completed with errors"
    exit 1
fi
