#!/bin/bash
# Script to read binary format memory.stat_bin

CGROUP_PATH="${1:-/sys/fs/cgroup/a}"
BIN_FILE="$CGROUP_PATH/memory.stat_bin"
READER="./readstat_bin"

# Check if binary reader exists, if not compile it
if [ ! -f "$READER" ]; then
    echo "Compiling readstat_bin..."
    gcc -o readstat_bin readstat_bin.c -Wall -Wextra
    if [ $? -ne 0 ]; then
        echo "Error: Failed to compile readstat_bin.c"
        exit 1
    fi
fi

# Check if binary file exists
if [ ! -f "$BIN_FILE" ]; then
    echo "Error: $BIN_FILE not found"
    echo "Make sure CONFIG_MEMCG_ATOMIC_COUNTER is enabled and cgroup exists"
    exit 1
fi

# Read and display
echo "Reading from: $BIN_FILE"
echo "========================================"
"$READER" "$BIN_FILE"











