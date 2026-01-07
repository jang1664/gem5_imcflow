#!/bin/bash

# Help message
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] <username> <file_pattern> [file_pattern2 ...]

Transfer files to vlsi-ferrari.snu.ac.kr using rsync over SSH.

Arguments:
    username        Remote username for ferrari server
    file_pattern    File pattern(s) to transfer (e.g., *.fsdb, output/*.log)

Options:
    -h, --help     Show this help message and exit

Examples:
    $0 jihoon.park *_gem5.fsdb
    $0 jihoon.park output/*.fsdb logs/*.txt
    $0 -h

Server Configuration:
    Host: vlsi-ferrari.snu.ac.kr
    Port: 1326
    Destination: ~/
EOF
}

# Check for help flag
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# Check if minimum required arguments are provided
if [ $# -lt 2 ]; then
    echo "Error: Missing required arguments"
    echo ""
    show_help
    exit 1
fi

# Server configuration
REMOTE_USER="$1"
REMOTE_HOST="vlsi-ferrari.snu.ac.kr"
REMOTE_PORT="1326"
REMOTE_PATH="~/"  # Change this to your desired destination path

# Shift to remove username from arguments, leaving only file patterns
shift

# rsync options:
# -avz: archive mode, verbose, compress
# -P: show progress and allow resuming
# -e: specify ssh with custom port
echo "Transferring files to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"
echo "Files to transfer: $@"
echo ""

rsync -avzP -e "ssh -p ${REMOTE_PORT}" "$@" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"

# Check if rsync was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "Transfer completed successfully!"
else
    echo ""
    echo "Transfer failed with error code $?"
    exit 1
fi
