#!/bin/bash
# Same as read_memory_stats_shell_ks.sh but set 3-field filter first so
# memory.stat.ks and memory.numa_stat.ks use BTF fast path (resolved cache).
# Run with: time ./read_memory_stats_shell_ks_filtered.sh

CGPATH="${CGPATH:-/sys/fs/cgroup}"
FILTER="vmstats.state[14],vmstats.state[16],vmstats.state[5]"

# Set filter on root cgroup (requires write permission / sudo)
echo "Setting 3-field filter on $CGPATH/memory.stat.ks and memory.numa_stat.ks ..."
echo "$FILTER" | sudo tee "$CGPATH/memory.stat.ks" >/dev/null || true
echo "$FILTER" | sudo tee "$CGPATH/memory.numa_stat.ks" >/dev/null || true

# Same loop as original: 1M iterations, read both files
for ((i=1; i<=1000000; i++)); do
    : > /dev/null < "$CGPATH/memory.stat.ks"
    : > /dev/null < "$CGPATH/memory.numa_stat.ks"
done
