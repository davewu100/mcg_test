# Build and benchmark: memory.stat (full) vs memory.stat.ks (BTF + cache)
# Usage:
#   make              # build all C programs
#   make set-filter   # set 3-field filter (needs sudo)
#   make set-full-filter  # set 16-field filter, max BTF/cache (needs sudo)
#   make bench        # legacy full vs 3-field .ks
#   make bench-full   # legacy full vs 16-field .ks (open-once, BTF+cache)
#   make clean        # remove binaries

CC      := gcc
CFLAGS  := -O2 -Wall
CGPATH  ?= /sys/fs/cgroup
FILTER  := vmstats.state[14],vmstats.state[16],vmstats.state[5]
# Max BTF/cache fields (KS_MAX_FIELDS=16): vmstats.state[0]..vmstats.state[15]
FULL_FILTER := vmstats.state[0],vmstats.state[1],vmstats.state[2],vmstats.state[3],vmstats.state[4],vmstats.state[5],vmstats.state[6],vmstats.state[7],vmstats.state[8],vmstats.state[9],vmstats.state[10],vmstats.state[11],vmstats.state[12],vmstats.state[13],vmstats.state[14],vmstats.state[15]

PROGS := read_memory_stats_open_once read_memory_stats_ks_open_once read_memory_stats_ks_full_open_once

all: $(PROGS)

read_memory_stats_open_once: read_memory_stats_open_once.c
	$(CC) $(CFLAGS) -o $@ $<

read_memory_stats_ks_open_once: read_memory_stats_ks_open_once.c
	$(CC) $(CFLAGS) -o $@ $<

read_memory_stats_ks_full_open_once: read_memory_stats_ks_full_open_once.c
	$(CC) $(CFLAGS) -o $@ $<

# Set 3-field filter on .ks files (needs sudo)
set-filter:
	@echo "Setting 3-field filter on $(CGPATH)/memory.stat.ks and memory.numa_stat.ks ..."
	@echo "$(FILTER)" | sudo tee $(CGPATH)/memory.stat.ks >/dev/null
	@echo "$(FILTER)" | sudo tee $(CGPATH)/memory.numa_stat.ks >/dev/null
	@echo "Done. Run 'make bench' to compare."

# Set 16-field filter (full BTF/cache path; needs sudo)
set-full-filter:
	@echo "Setting 16-field filter on $(CGPATH)/memory.stat.ks and memory.numa_stat.ks ..."
	@echo "$(FULL_FILTER)" | sudo tee $(CGPATH)/memory.stat.ks >/dev/null
	@echo "$(FULL_FILTER)" | sudo tee $(CGPATH)/memory.numa_stat.ks >/dev/null
	@echo "Done. Run 'make bench-full' or ./read_memory_stats_ks_full_open_once"

# Run both: full (memory.stat) vs 3-field .ks
bench: all
	@echo "=== memory.stat + memory.numa_stat (full, legacy) ==="
	@time ./read_memory_stats_open_once
	@echo ""
	@echo "=== memory.stat.ks + memory.numa_stat.ks (3-field filter) ==="
	@time ./read_memory_stats_ks_open_once
	@echo ""
	@echo "Done. Compare 'real' time above."

# Run: full legacy vs 16-field .ks (open-once, BTF + resolved cache)
bench-full: all
	@echo "=== memory.stat + memory.numa_stat (full, legacy) ==="
	@time ./read_memory_stats_open_once
	@echo ""
	@echo "=== memory.stat.ks + memory.numa_stat.ks (16-field, BTF+cache) ==="
	@time sudo ./read_memory_stats_ks_full_open_once
	@echo ""
	@echo "Done. Compare 'real' time above."

clean:
	rm -f $(PROGS)

.PHONY: all set-filter set-full-filter bench bench-full clean
