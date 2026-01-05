#!/bin/bash
# Full MMIO transaction test: gem5 + VCS with actual read/write operations

set -e

GEM5_DIR="/root/project/imcflow/pmap/ISA_sim/gem5"
VCS_DIR="/root/dpi_example/socket_test"

echo "=========================================="
echo "  gem5 + VCS MMIO Transaction Test"
echo "=========================================="
echo ""

# Check binaries exist
if [ ! -f "$VCS_DIR/simv_socket" ]; then
    echo "[ERROR] VCS simulation not found!"
    exit 1
fi

if [ ! -f "$GEM5_DIR/build/X86/gem5.opt" ]; then
    echo "[ERROR] gem5 not built!"
    exit 1
fi

if [ ! -f "$GEM5_DIR/tests/test-progs/imcflow/mmio_test" ]; then
    echo "[ERROR] MMIO test binary not found!"
    echo "Compiling..."
    cd "$GEM5_DIR/tests/test-progs/imcflow"
    gcc -static -m64 mmio_test.c -o mmio_test
    echo "✓ Compiled mmio_test"
fi

# Kill any existing simulations
pkill -f simv_socket || true
sleep 1

# Start VCS
echo "[1] Starting VCS simulation..."
cd "$VCS_DIR"
./simv_socket > vcs_mmio.log 2>&1 &
VCS_PID=$!
echo "    VCS PID: $VCS_PID"

# Wait for VCS
echo "[2] Waiting for VCS server..."
sleep 3

if ! kill -0 $VCS_PID 2>/dev/null; then
    echo "[ERROR] VCS died!"
    cat vcs_mmio.log
    exit 1
fi

if ! netstat -tuln | grep -q ":9999.*LISTEN"; then
    echo "[ERROR] VCS not listening on port 9999!"
    kill $VCS_PID 2>/dev/null || true
    cat vcs_mmio.log
    exit 1
fi

echo "    ✓ VCS ready"
echo ""

# Run gem5 with MMIO test
echo "[3] Starting gem5 with MMIO test binary..."
cd "$GEM5_DIR"
./build/X86/gem5.opt \
    --debug-flags=ImcflowPIO \
    configs/imcflow/test_mmio.py 2>&1 | tee gem5_mmio.log

GEM5_STATUS=${PIPESTATUS[0]}

echo ""
echo "[4] Cleaning up..."

if kill -0 $VCS_PID 2>/dev/null; then
    kill $VCS_PID 2>/dev/null || true
    sleep 1
    kill -9 $VCS_PID 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo "  Test Results"
echo "=========================================="

if [ $GEM5_STATUS -eq 0 ]; then
    echo "✓ gem5 MMIO test completed successfully"
else
    echo "✗ gem5 MMIO test failed"
fi

echo ""
echo "Logs:"
echo "  VCS:  $VCS_DIR/vcs_mmio.log"
echo "  gem5: $GEM5_DIR/gem5_mmio.log"
echo ""

echo "=========================================="
echo "  VCS Transactions"
echo "=========================================="
grep -E "\[DPI-C\] (Received|Sent)" "$VCS_DIR/vcs_mmio.log" | tail -20

echo ""
echo "=========================================="
echo "  gem5 MMIO Operations"
echo "=========================================="
grep "ImcflowPIO" "$GEM5_DIR/gem5_mmio.log" | tail -20 || echo "(No debug output - run with --debug-flags=ImcflowPIO)"

exit $GEM5_STATUS
