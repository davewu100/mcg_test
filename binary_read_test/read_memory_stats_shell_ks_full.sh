#!/bin/bash
# Full-field read of memory.stat.ks and memory.numa_stat.ks via BTF + cache.
# Uses KS_MAX_FIELDS=16: vmstats.state[0]..vmstats.state[15].
# Run once: set 16-field filter (sudo), then 1M read iterations on both files.
#   time ./read_memory_stats_shell_ks_full.sh

CGPATH="${CGPATH:-/sys/fs/cgroup}"
# Max fields for .ks schema (must match kernel KS_MAX_FIELDS=16)
FIELDS=""
for i in $(seq 0 15); do
  [ -n "$FIELDS" ] && FIELDS="$FIELDS,"
  FIELDS="${FIELDS}vmstats.state[$i]"
done

echo "Setting 16-field filter on $CGPATH/memory.stat.ks and memory.numa_stat.ks ..."
echo "$FIELDS" | sudo tee "$CGPATH/memory.stat.ks" >/dev/null || true
echo "$FIELDS" | sudo tee "$CGPATH/memory.numa_stat.ks" >/dev/null || true

echo "Reading both .ks files 1M times (BTF + resolved cache path)..."
for ((i=1; i<=1000000; i++)); do
  : > /dev/null < "$CGPATH/memory.stat.ks"
  : > /dev/null < "$CGPATH/memory.numa_stat.ks"
done
