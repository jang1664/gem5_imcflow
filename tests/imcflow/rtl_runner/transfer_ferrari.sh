#!/bin/bash

# Check if any arguments are provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <file_pattern> [file_pattern2 ...]"
    echo "Example: $0 *_gem5.fsdb"
    echo "Example: $0 output/*.fsdb"
    exit 1
fi

# Server configuration
REMOTE_USER="jihoon.park"
REMOTE_HOST="vlsi-ferrari.snu.ac.kr"
REMOTE_PORT="1326"
REMOTE_PATH="~/"  # Change this to your desired destination path

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
