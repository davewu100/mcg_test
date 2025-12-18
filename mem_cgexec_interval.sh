#!/bin/bash
# Uses cgexec to launch processes directly into target cgroups, with optional inter-launch interval
set -euo pipefail

cgroup_top_dir="/sys/fs/cgroup/a"

# Args: [num_leaves] [size_per_worker] [seconds] [interval_between_launches]
#   num_leaves: number of cgroup leaves to target (a/b/c/0 .. a/b/c/(num_leaves-1))
#   size_per_worker: e.g., 300M
#   seconds: runtime per worker (passed to alloc)
#   interval_between_launches: seconds (can be fractional), sleep between starting each worker
NUM="${1:-26}"
SIZE="${2:-100M}"
SECS="${3:-2}"
INTERVAL="${4:-0}"

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

# Determine sleep command (supports fractional seconds with sleep(1) in coreutils/busybox)
sleep_interval() {
  local s="$1"
  # Treat empty or zero as no-op
  if [[ -z "${s}" || "${s}" == "0" || "${s}" == "0.0" ]]; then
    return 0
  fi
  sleep "${s}" || true
}

ALLOC_ABS=$(realpath "${ALLOC}")

pids=()
for i in $(seq 0 $((NUM-1))); do
  leaf="${cgroup_top_dir}/b/c/${i}"
  if [[ ! -d "${leaf}" ]]; then
    echo "Missing leaf ${leaf}" >&2
    exit 1
  fi

  # cgexec syntax: cgexec -g controller:path command
  # For cgroup v2, the path is relative to /sys/fs/cgroup/
  cgexec -g memory:a/b/c/${i} "${ALLOC_ABS}" "${SIZE}" "${SECS}" &
  pid=$!
  pids+=("$pid")
  echo "Started process ${pid} in cgroup a/b/c/${i}"

  # Sleep between launches, except after the last one
  if [[ $i -lt $((NUM-1)) ]]; then
    sleep_interval "${INTERVAL}"
  fi
done

# Wait for all
status=0
for p in "${pids[@]}"; do
  if ! wait "$p"; then
    status=1
  fi
done

if [[ $status -eq 0 ]]; then
  echo "All memory workers completed."
else
  echo "One or more workers exited with non-zero status." >&2
fi

exit "$status"
