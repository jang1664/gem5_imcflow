#!/bin/bash
# Communication test: gem5 ↔ VCS bidirectional data flow

set -e

GEM5_DIR="/root/project/imcflow/pmap/ISA_sim/gem5"
VCS_DIR="/root/project/imcflow/pmap/ISA_sim/gem5/dpi_example/socket_test"

echo "=========================================="
echo "  gem5 ↔ VCS Communication Test"
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

# Check if test binary exists
if [ ! -f "$GEM5_DIR/tests/test-progs/imcflow/mmio_communication_test" ]; then
    echo "[ERROR] Test program not compiled!"
    echo "Run: cd $GEM5_DIR/tests/test-progs/imcflow && gcc -static -o mmio_communication_test mmio_communication_test.c"
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
for i in {1..10}; do
    if netstat -tuln | grep -q ":9999 "; then
        echo "    ✓ VCS server listening on port 9999"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "    ✗ Timeout waiting for VCS server"
        kill $VCS_PID 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

# Run gem5
echo "[3] Running gem5 communication test..."
echo ""
echo "=========================================="
echo "  Data Flow Visualization"
echo "=========================================="
echo ""

cd "$GEM5_DIR"
./build/X86/gem5.opt configs/imcflow/test_communication.py > gem5.log 2>&1
GEM5_EXIT=$?

echo ""
echo "=========================================="
echo ""

# Wait for VCS to finish
echo "[4] Waiting for VCS to finish..."
sleep 2
kill $VCS_PID 2>/dev/null || true
wait $VCS_PID 2>/dev/null || true

# Check results
echo ""
echo "=========================================="
echo "  Test Results"
echo "=========================================="

if [ $GEM5_EXIT -eq 0 ]; then
    echo "✓ gem5 completed successfully"
else
    echo "✗ gem5 failed with status $GEM5_EXIT"
fi

echo ""
echo "Logs:"
echo "  VCS:  $VCS_DIR/vcs.log"
echo "  gem5: $GEM5_DIR/gem5.log"
echo ""

# Show VCS transaction log
echo "=========================================="
echo "  VCS Transaction Log"
echo "=========================================="
grep -E "\[DPI-C\] (Received|Sent)" "$VCS_DIR/vcs.log" | tail -20 || echo "No transactions found"
echo ""

# Show gem5 output
echo "=========================================="
echo "  gem5 Output"
echo "=========================================="
cat "$GEM5_DIR/gem5.log" | grep -E "(gem5|VCS|WRITE|READ|Test|Communication)" | tail -30
echo ""
