#!/bin/bash

time (
    for ((i=1; i<=10000; i++)); do
        cat /sys/fs/cgroup/memory.stat \
            /sys/fs/cgroup/memory.numa_stat > /dev/null
    done
)
