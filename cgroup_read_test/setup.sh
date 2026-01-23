for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance | sudo tee $g; done
./setup_mem.sh
sleep 2
./mem_cgexec.sh
