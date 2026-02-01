for ((i=1; i<=1000000; i++)); do
    : > /dev/null < /sys/fs/cgroup/memory.stat
done
