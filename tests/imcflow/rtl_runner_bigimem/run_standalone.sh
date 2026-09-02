#!/bin/bash
# Standalone RTL Runner for non-TVM binaries
# Usage: ./run_standalone.sh <binary_path> [gdb] [log_dir] [imc_size] [socket_port] [binary_args...]
# Examples:
#   ./run_standalone.sh /path/to/program_scan_reg no ./logs 266368 1234 ./scan_reg_files0
#   ./run_standalone.sh /path/to/my_binary yes ./logs 266368 9999 --arg1 val1 --arg2 val2

set -e  # Exit on error

# Directory structure
BUILD_DIR="build"

BINARY_PATH=${1:?"Usage: $0 <binary_path> [gdb] [log_dir] [imc_size] [socket_port] [binary_args...]"}
GDB=${2:-"no"}
LOG_DIR=${3:-"./logs"}
IMC_SIZE=${4:-"266368"}
SOCKET_PORT_ARG=${5:-""}

# Capture extra arguments (arguments 6 onwards) to pass to the binary
EXTRA_ARGS="${@:6}"

BINARY_NAME=$(basename "$BINARY_PATH")

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

echo "  RTL Runner - Standalone Binary Execution"
echo "========================================"
echo "Binary:        $BINARY_PATH"
echo "GDB Mode:      $GDB"
echo "Socket Port:   $SOCKET_PORT"
echo "SRAM Backdoor: $([ "$SRAM_BACKDOOR" = "1" ] && echo "ENABLED (fast)" || echo "DISABLED (accurate)")"
if [ -n "$EXTRA_ARGS" ]; then
    echo "Binary Args:   $EXTRA_ARGS"
fi
echo ""

# Verify binary exists
if [ ! -f "$BINARY_PATH" ]; then
    echo "ERROR: Binary not found at $BINARY_PATH"
    exit 1
fi

# Create log directory
mkdir -p "$LOG_DIR"
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
rm -f "$LOG_DIR/vcs_sim.log" "$LOG_DIR/gem5_output.log"

# Start VCS simulation in background
FSDB_FILE="$LOG_DIR/imcflow_gem5_standalone.fsdb"
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

# Run gem5 with standalone binary
echo "=== Starting gem5 with standalone binary ==="
echo "Running: $GEM5_BIN with run_imcflow_rtl.py --standalone"
echo "gem5 log: $LOG_DIR/gem5_output.log"
echo ""

# Set imcflow log directory to redirect simulator logs
export IMCFLOW_LOG_DIR="$LOG_DIR"

# Build gem5 command using array (handles paths with spaces correctly)
GEM5_CMD=(
    "$GEM5_BIN"
    "--outdir=$LOG_DIR"
    "$GEM5_HOME/configs/imcflow/run_imcflow_rtl.py"
    "--binary" "$BINARY_PATH"
    "--standalone"
    "--vcs-port" "$SOCKET_PORT"
    "--imc-size" "$IMC_SIZE"
)

# Add extra args if provided (these become the binary's actual arguments)
if [ -n "$EXTRA_ARGS" ]; then
    GEM5_CMD+=("--extra-args" "$EXTRA_ARGS")
    echo "[*] Binary arguments: $EXTRA_ARGS"
fi

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
