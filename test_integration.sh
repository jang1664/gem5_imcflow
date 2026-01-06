#!/bin/bash
# Integration test: gem5 + VCS via socket

set -e

GEM5_DIR="/root/project/imcflow/pmap/ISA_sim/gem5"
VCS_DIR="/root/project/imcflow/pmap/ISA_sim/gem5/dpi_example/socket_test"

echo "=========================================="
echo "  gem5 + VCS Socket Integration Test"
echo "=========================================="
echo ""

# Check if VCS simulation exists
if [ ! -f "$VCS_DIR/simv_socket" ]; then
    echo "[ERROR] VCS simulation not found!"
    echo "Run: cd $VCS_DIR && make compile"
    exit 1
fi

# Check if gem5 exists
if [ ! -f "$GEM5_DIR/build/X86/gem5.opt" ]; then
    echo "[ERROR] gem5 not built!"
    echo "Run: cd $GEM5_DIR && scons build/X86/gem5.opt -j\$(nproc)"
    exit 1
fi

# Kill any existing simulations
pkill -f simv_socket || true
sleep 1

# Start VCS simulation in background
echo "[1] Starting VCS simulation..."
cd "$VCS_DIR"
./simv_socket > vcs.log 2>&1 &
VCS_PID=$!
echo "    VCS PID: $VCS_PID"

# Wait for VCS to be ready
echo "[2] Waiting for VCS server to be ready..."
sleep 3

# Check if VCS is still running
if ! kill -0 $VCS_PID 2>/dev/null; then
    echo "[ERROR] VCS simulation died!"
    cat vcs.log
    exit 1
fi

# Check if port is listening
if ! netstat -tuln | grep -q ":9999.*LISTEN"; then
    echo "[ERROR] VCS server not listening on port 9999!"
    kill $VCS_PID 2>/dev/null || true
    cat vcs.log
    exit 1
fi

echo "    VCS server ready on port 9999"
echo ""

# Run gem5
echo "[3] Starting gem5 simulation..."
cd "$GEM5_DIR"
./build/X86/gem5.opt configs/imcflow/test_socket_simple.py 2>&1 | tee gem5.log

# Get exit status
GEM5_STATUS=${PIPESTATUS[0]}

echo ""
echo "[4] Cleaning up..."

# Kill VCS
if kill -0 $VCS_PID 2>/dev/null; then
    echo "    Stopping VCS simulation..."
    kill $VCS_PID 2>/dev/null || true
    sleep 1
    kill -9 $VCS_PID 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo "  Test Results"
echo "=========================================="

if [ $GEM5_STATUS -eq 0 ]; then
    echo "✓ gem5 completed successfully"
else
    echo "✗ gem5 failed with status $GEM5_STATUS"
fi

echo ""
echo "Logs:"
echo "  VCS:  $VCS_DIR/vcs.log"
echo "  gem5: $GEM5_DIR/gem5.log"
echo ""

# Show VCS log
echo "=========================================="
echo "  VCS Output (last 30 lines)"
echo "=========================================="
tail -30 "$VCS_DIR/vcs.log"

exit $GEM5_STATUS
