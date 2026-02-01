# Build and benchmark: memory.stat (full) vs memory.stat.ks (filtered, open-once)
# Usage:
#   make              # build both C programs
#   make set-filter   # set 3-field filter (needs sudo, run once)
#   make bench        # run both benchmarks and compare
#   make clean        # remove binaries

CC      := gcc
CFLAGS  := -O2 -Wall
CGPATH  ?= /sys/fs/cgroup
FILTER  := vmstats.state[14],vmstats.state[16],vmstats.state[5]

PROGS := read_memory_stats_open_once read_memory_stats_ks_open_once

all: $(PROGS)

read_memory_stats_open_once: read_memory_stats_open_once.c
	$(CC) $(CFLAGS) -o $@ $<

read_memory_stats_ks_open_once: read_memory_stats_ks_open_once.c
	$(CC) $(CFLAGS) -o $@ $<

# Set 3-field filter on .ks files (run once before bench; needs sudo)
set-filter:
	@echo "Setting filter on $(CGPATH)/memory.stat.ks and memory.numa_stat.ks ..."
	@echo "$(FILTER)" | sudo tee $(CGPATH)/memory.stat.ks >/dev/null
	@echo "$(FILTER)" | sudo tee $(CGPATH)/memory.numa_stat.ks >/dev/null
	@echo "Done. Run 'make bench' to compare."

# Run both: full (memory.stat) vs filtered (.ks), same open-once + 1M lseek+read
bench: all
	@echo "=== memory.stat + memory.numa_stat (full, legacy) ==="
	@time ./read_memory_stats_open_once
	@echo ""
	@echo "=== memory.stat.ks + memory.numa_stat.ks (3-field filter) ==="
	@time ./read_memory_stats_ks_open_once
	@echo ""
	@echo "Done. Compare 'real' time above."

clean:
	rm -f $(PROGS)

.PHONY: all set-filter bench clean
