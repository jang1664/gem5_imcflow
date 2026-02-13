#!/bin/bash
# RTL Runner for TVM Workloads
# Usage: ./run.sh <binary_name> <gdb_mode> [test_name] [log_dir] [imc_size] [socket_port]
# Examples:
#   ./run.sh tvm_host_runner no one_conv
#   ./run.sh tvm_host_runner yes resnet8
#   ./run.sh tvm_host_runner no one_conv /path/to/logs 266368 10001

set -e  # Exit on error

# Directory structure
BUILD_DIR="build"

BINARY=${1:-"execute_graph"}
GDB=${2:-"no"}
TEST_NAME=${3:-"default_test"}
LOG_DIR=${4:-"./logs"}
IMC_SIZE=${5:-"266368"}
SOCKET_PORT_ARG=${6:-""}

# Set TVM build directory based on test name (uses per-test host_binary_make)
TVM_BUILD_DIR=~/project/tvm/tvm_practice/test_imcflow/codegen/${TEST_NAME}/host_binary_make/build

echo "========================================"

# Set SOCKET_PORT: 1) from argument, 2) from env var, 3) default 9999
if [ -n "$SOCKET_PORT_ARG" ]; then
    SOCKET_PORT="$SOCKET_PORT_ARG"
else
    : "${SOCKET_PORT:=9999}"
fi
export SOCKET_PORT

# Set SRAM backdoor enable/disable (default: enabled for performance)
: "${SRAM_BACKDOOR:=1}"
export SRAM_BACKDOOR

echo "  RTL Runner - TVM Workload Execution"
echo "========================================"
echo "Binary:        $BINARY"
echo "GDB Mode:      $GDB"
echo "Test Name:     $TEST_NAME"
echo "Socket Port:   $SOCKET_PORT"
echo "SRAM Backdoor: $([ "$SRAM_BACKDOOR" = "1" ] && echo "ENABLED (fast)" || echo "DISABLED (accurate)")"
echo ""

# Create directories (per-test isolation for concurrent execution)
echo "Setting up directories..."
BINARY_DIR="binaries/${TEST_NAME}"
MLF_DIR="mlf_${TEST_NAME}"
mkdir -p "$BINARY_DIR"
mkdir -p "$LOG_DIR"
mkdir -p test_outputs/$TEST_NAME
echo ""

# Copy TVM binaries and MLF
echo "Copying TVM binaries and model files..."
if [ ! -f "$TVM_BUILD_DIR/$BINARY" ]; then
    echo "ERROR: Binary not found at $TVM_BUILD_DIR/$BINARY"
    echo "Please compile the TVM host runner first"
    exit 1
fi

cp $TVM_BUILD_DIR/$BINARY "$BINARY_DIR/"
echo "  ✓ Copied $BINARY to $BINARY_DIR/"

if [ -d "$TVM_BUILD_DIR/mlf" ]; then
    rm -rf "$MLF_DIR"
    cp -r $TVM_BUILD_DIR/mlf "$MLF_DIR"
    echo "  ✓ Copied MLF to $MLF_DIR/"
else
    echo "  ! Warning: MLF directory not found at $TVM_BUILD_DIR/mlf"
fi

# Copy test inputs if they exist
if [ -d "$TVM_BUILD_DIR/test_inputs/$TEST_NAME" ]; then
    mkdir -p test_inputs
    cp -r $TVM_BUILD_DIR/test_inputs/$TEST_NAME test_inputs/
    echo "  ✓ Copied test inputs for $TEST_NAME"
fi

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
rm -f "$LOG_DIR/vcs_sim.log" "$LOG_DIR/gem5_output.log"

# Start VCS simulation in background (with per-test waveform file in LOG_DIR)
FSDB_FILE="$LOG_DIR/imcflow_gem5_${TEST_NAME}.fsdb"
echo "=== Starting VCS RTL simulation ==="
echo "VCS listening on port $SOCKET_PORT..."
echo "VCS log: $LOG_DIR/vcs_sim.log"
echo "FSIM logs: $LOG_DIR/fsim_logs/"
echo "Waveform: $FSDB_FILE"
echo "SRAM Backdoor: $([ "$SRAM_BACKDOOR" = "1" ] && echo "ENABLED" || echo "DISABLED")"
$BUILD_DIR/simv_imcflow_gem5 +SOCKET_PORT=$SOCKET_PORT +SRAM_BACKDOOR=$SRAM_BACKDOOR +FSIM_LOG_DIR=$LOG_DIR/fsim_logs +fsdbfile+${FSDB_FILE} +fsdb+autoflush > "$LOG_DIR/vcs_sim.log" 2>&1 &
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
    tail -30 "$LOG_DIR/vcs_sim.log"
    exit 1
fi

echo "VCS simulation is running, ready for gem5 connection"
echo ""

# Run gem5 with ImcflowPIOSocket device
echo "=== Starting gem5 with TVM workload ==="
echo "Running: $GEM5_BIN with run_imcflow_rtl.py"
echo "gem5 log: $LOG_DIR/gem5_output.log"
echo ""

# Set imcflow log directory to redirect simulator logs
export IMCFLOW_LOG_DIR="$LOG_DIR"

# Build gem5 command using array (handles paths with spaces correctly)
GEM5_CMD=(
    "$GEM5_BIN"
    "--outdir=$LOG_DIR"
    "$GEM5_HOME/configs/imcflow/run_imcflow_rtl.py"
    "--binary" "$BINARY_DIR/$BINARY"
    "--test-name" "$TEST_NAME"
    "--vcs-port" "$SOCKET_PORT"
    "--runner-name" "rtl_runner"
    "--imc-size" "$IMC_SIZE"
    "--mlf-dir" "$MLF_DIR"
)

# Add GDB flag if requested
if [ "$GDB" == "yes" ]; then
    GEM5_CMD+=("--gdb")
    echo "[*] GDB debugging enabled on port 7000"
fi

# Run gem5 and save output
"${GEM5_CMD[@]}" 2>&1 | tee "$LOG_DIR/gem5_output.log"

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
tail -40 "$LOG_DIR/vcs_sim.log"
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
    echo "  - VCS log: $LOG_DIR/vcs_sim.log"
    echo "  - gem5 log: $LOG_DIR/gem5_output.log"
    echo "  - gem5 debug logs: $LOG_DIR/"
    echo ""
    echo "Build artifacts:"
    echo "  - VCS binary: $BUILD_DIR/simv_imcflow_gem5"
    echo "  - Waveform: $FSDB_FILE (if generated)"
    exit 0
else
    echo "========================================"
    echo "  ✗ SIMULATION FAILED"
    echo "========================================"
    echo ""
    echo "Check logs for details:"
    echo "  - VCS log: $LOG_DIR/vcs_sim.log"
    echo "  - gem5 log: $LOG_DIR/gem5_output.log"
    exit 1
fi
