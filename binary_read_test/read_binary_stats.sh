#!/bin/bash
# Script to read binary format memory.stat_bin and memory.numa_stat_bin
# Similar to read.sh but uses binary interface

BINARY="./readstats_bin"

# Check if binary reader exists, if not compile it
if [ ! -f "$BINARY" ]; then
    echo "Compiling readstats_bin..."
    gcc -o readstats_bin readstats_bin.c -Wall -Wextra
    if [ $? -ne 0 ]; then
        echo "Error: Failed to compile readstats_bin.c"
        exit 1
    fi
fi

# Check if binary files exist
CGROUP_PATH="${1:-/sys/fs/cgroup/a}"
STAT_BIN="$CGROUP_PATH/memory.stat_bin"
NUMA_STAT_BIN="$CGROUP_PATH/memory.numa_stat_bin"

if [ ! -f "$STAT_BIN" ]; then
    echo "Error: $STAT_BIN not found"
    echo "Make sure CONFIG_MEMCG_ATOMIC_COUNTER is enabled and cgroup exists"
    exit 1
fi

if [ ! -f "$NUMA_STAT_BIN" ]; then
    echo "Error: $NUMA_STAT_BIN not found"
    echo "Make sure CONFIG_MEMCG_ATOMIC_COUNTER is enabled and cgroup exists"
    exit 1
fi

# Run the binary reader with number of iterations
ITERATIONS="${2:-10}"
echo "Reading binary stats with $ITERATIONS iterations..."
echo "========================================"
time "$BINARY" "$ITERATIONS"

