#!/bin/bash

set -euo pipefail

cgroup_dir="/sys/fs/cgroup"

# Ensure cgroup v2 is mounted
if ! mount | grep -q "cgroup2 on ${cgroup_dir}"; then
  echo "cgroup v2 not mounted at ${cgroup_dir}" >&2
  exit 1
fi

# Build hierarchy
mkdir -p "${cgroup_dir}/a/b/c/d1"
mkdir -p "${cgroup_dir}/a/b/c/d2"

# Enable controllers at each level that will host children
subsystems="+cpu +memory +io"
echo "$subsystems" > "${cgroup_dir}/cgroup.subtree_control" || true
echo "$subsystems" > "${cgroup_dir}/a/cgroup.subtree_control" || true
echo "$subsystems" > "${cgroup_dir}/a/b/cgroup.subtree_control" || true
echo "$subsystems" > "${cgroup_dir}/a/b/c/cgroup.subtree_control" || true

cgroup_top_dir="${cgroup_dir}/a"

# Parent limits: disable swap, set a parent cap large enough to fit leaves
# Adjust as needed for your test rig.
echo 0   > "${cgroup_top_dir}/memory.swap.max"
echo 21474836480 > "${cgroup_top_dir}/memory.max"      # parent budget, 20G
echo 16106127360 > "${cgroup_top_dir}/memory.high"    # throttle at 15G before hard OOM at 20G

# Create N leaves under /a/b/c and set per-leaf limits
N="${N:-26}"                     # number of leaves (default 0..25)
LEAF_MAX="${LEAF_MAX:-83886080}" # per-leaf hard cap (80 MiB)
LEAF_HIGH="${LEAF_HIGH:-67108864}" # per-leaf soft throttle (64 MiB)

for i in $(seq 0 $((N-1))); do
  leaf="${cgroup_top_dir}/b/c/${i}"
  mkdir -p "${leaf}"
  # It's legal to set leaf limits even if leaf has no children (leaf groups host tasks).
  echo 0          > "${leaf}/memory.swap.max"
  echo "${LEAF_HIGH}" > "${leaf}/memory.high"
  echo "${LEAF_MAX}"  > "${leaf}/memory.max"
  # Enable delegation to allow processes to be moved into this cgroup
  chown -R $(whoami):$(whoami) "${leaf}" 2>/dev/null || true
done

echo "Memory cgroup hierarchy ready under ${cgroup_top_dir} with ${N} leaves."
