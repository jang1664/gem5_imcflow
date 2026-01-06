#!/bin/bash
# Test script for MMIO communication (Test 1 & 2: Write 8 and Read 8)
# This script runs the RTL testbench with gem5 executing mmio_communication_test

set -e  # Exit on error

# Directory structure
BUILD_DIR="build"
LOGS_DIR="logs"
TEST_NAME="mmio_comm_test"
BINARY_PATH="../../test-progs/imcflow/mmio_communication_test"

echo "========================================"
echo "  MMIO Communication Test (RTL + gem5)"
echo "========================================"
echo "Test: Write 8 + Read 8 values"
echo ""

# Check if binary exists
if [ ! -f "$BINARY_PATH" ]; then
    echo "ERROR: Test binary not found at $BINARY_PATH"
    echo "Please compile mmio_communication_test.c first"
    exit 1
fi

# Create directories
echo "Setting up directories..."
mkdir -p binaries
mkdir -p $LOGS_DIR
mkdir -p test_outputs/$TEST_NAME

# Copy test binary
echo "Preparing test binary..."
cp $BINARY_PATH binaries/mmio_communication_test
echo "Binary copied to binaries/"
echo ""

# Select gem5 binary
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
$BUILD_DIR/simv_imcflow_gem5 > $LOGS_DIR/vcs_sim.log 2>&1 &
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
echo "=== Starting gem5 with MMIO test ==="
echo "Running: $GEM5_BIN with test_communication.py"
echo "gem5 log: $LOGS_DIR/gem5_output.log"
echo ""

# Note: Debug flags require TRACING_ON compilation, commented out for now
# DFLAGS="ImcflowPIOSocket,AddrRanges"

# Run gem5 and save output (test_communication.py doesn't take CLI args, it uses the hardcoded binary)
$GEM5_BIN $GEM5_HOME/configs/imcflow/test_communication.py \
    2>&1 | tee $LOGS_DIR/gem5_output.log

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
    echo "  ✓ TEST PASSED"
    echo "========================================"
    echo ""
    echo "Logs saved:"
    echo "  - VCS log: $LOGS_DIR/vcs_sim.log"
    echo "  - gem5 log: $LOGS_DIR/gem5_output.log"
    echo "  - gem5 m5out: m5out/"
    echo ""
    echo "Build artifacts:"
    echo "  - VCS binary: $BUILD_DIR/simv_imcflow_gem5"
    echo "  - Build files: $BUILD_DIR/"
    exit 0
else
    echo "========================================"
    echo "  ✗ TEST FAILED"
    echo "========================================"
    echo ""
    echo "Check logs for details:"
    echo "  - VCS log: $LOGS_DIR/vcs_sim.log"
    echo "  - gem5 log: $LOGS_DIR/gem5_output.log"
    exit 1
fi
