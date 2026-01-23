#!/bin/bash
# Uses cgexec to launch processes directly into target cgroups
set -euo pipefail

cgroup_top_dir="/sys/fs/cgroup/a"

# Args: [num_leaves] [size_per_worker] [seconds]
NUM="${1:-26}"
# SIZE="${2:-200M}"
SIZE="${2:-2M}"
SECS="${3:-200}"

ALLOC="${ALLOC_BIN:-./alloc}"
if [[ ! -x "${ALLOC}" ]]; then
  echo "Allocator ${ALLOC} not found or not executable." >&2
  exit 1
fi

# Check if cgexec is available
if ! command -v cgexec &>/dev/null; then
  echo "cgexec not found. Install cgroup-tools package:" >&2
  echo "  apt-get install cgroup-tools   # Debian/Ubuntu" >&2
  echo "  yum install libcgroup-tools    # CentOS/RHEL" >&2
  exit 1
fi

ALLOC_ABS=$(realpath "${ALLOC}")

pids=()
for i in $(seq 0 $((NUM-1))); do
  leaf="${cgroup_top_dir}/b/c/${i}"
  [[ -d "${leaf}" ]] || { echo "Missing leaf ${leaf}" >&2; exit 1; }

  # cgexec syntax: cgexec -g controller:path command
  # For cgroup v2, the path is relative to /sys/fs/cgroup/
  cgexec -g memory:a/b/c/${i} "${ALLOC_ABS}" "${SIZE}" "${SECS}" &
  pid=$!
  pids+=($pid)

  echo "Started process ${pid} in cgroup a/b/c/${i}"
done

# Wait for all
for p in "${pids[@]}"; do
  wait "$p" || true
done

echo "All memory workers completed."

