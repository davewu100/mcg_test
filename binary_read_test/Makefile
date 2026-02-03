# Build and benchmark: memory.stat (full) vs memory.stat.ks (BTF + cache)
# Usage:
#   make              # build all C programs
#   make set-filter   # set 3-field filter (writes to CGPATH; no sudo if CGPATH is writable)
#   make set-filter-16/32/64, set-full-filter  # N-field + flush
#   make bench-16 / bench-32 / bench-64 / bench-full  # legacy vs N-field .ks (with flush)
#   make clean        # remove binaries
#
# CGPATH: cgroup to use (default /sys/fs/cgroup = root; needs root to write).
# To avoid sudo: create a cgroup you own, e.g.:
#   sudo mkdir -p /sys/fs/cgroup/bench && sudo chown $$USER /sys/fs/cgroup/bench
#   make bench CGPATH=/sys/fs/cgroup/bench
# (set-filter will then write without sudo.)

CC      := gcc
CFLAGS  := -O2 -Wall
CGPATH  ?= /sys/fs/cgroup
# With "flush" so ks does full flush like legacy (fair comparison)
FILTER  := flush,vmstats.state[14],vmstats.state[16],vmstats.state[5]
# N-field + flush: vmstats.state[0]..[N-1]
FULL_FILTER_16 := flush,$(shell seq 0 15  | sed 's/.*/vmstats.state[&]/' | paste -sd, -)
FULL_FILTER_32 := flush,$(shell seq 0 31  | sed 's/.*/vmstats.state[&]/' | paste -sd, -)
FULL_FILTER_64 := flush,$(shell seq 0 63  | sed 's/.*/vmstats.state[&]/' | paste -sd, -)
FULL_FILTER    := flush,$(shell seq 0 127 | sed 's/.*/vmstats.state[&]/' | paste -sd, -)

PROGS := read_memory_stats_open_once read_memory_stats_ks_open_once read_memory_stats_ks_full_open_once

all: $(PROGS)

read_memory_stats_open_once: read_memory_stats_open_once.c
	$(CC) $(CFLAGS) -o $@ $<

read_memory_stats_ks_open_once: read_memory_stats_ks_open_once.c
	$(CC) $(CFLAGS) -o $@ $<

read_memory_stats_ks_full_open_once: read_memory_stats_ks_full_open_once.c
	$(CC) $(CFLAGS) -o $@ $<

# Set N-field + flush filter (writes to CGPATH; no sudo if CGPATH is writable by you)
set-filter:
	@echo "Setting 3-field + flush filter on $(CGPATH)/memory.stat.ks and memory.numa_stat.ks ..."
	@echo "$(FILTER)" > $(CGPATH)/memory.stat.ks && echo "$(FILTER)" > $(CGPATH)/memory.numa_stat.ks && echo "Done. Run 'make bench' to compare." || (echo "Failed (need write access to $(CGPATH)? Try: sudo make set-filter or use CGPATH=... a cgroup you own)" && exit 1)

set-filter-16:
	@echo "Setting 16-field + flush filter on $(CGPATH)/memory.stat.ks and memory.numa_stat.ks ..."
	@echo "$(FULL_FILTER_16)" > $(CGPATH)/memory.stat.ks && echo "$(FULL_FILTER_16)" > $(CGPATH)/memory.numa_stat.ks && echo "Done. Run 'make bench-16'." || (echo "Failed (need write access to $(CGPATH))" && exit 1)

set-filter-32:
	@echo "Setting 32-field + flush filter on $(CGPATH)/memory.stat.ks and memory.numa_stat.ks ..."
	@echo "$(FULL_FILTER_32)" > $(CGPATH)/memory.stat.ks && echo "$(FULL_FILTER_32)" > $(CGPATH)/memory.numa_stat.ks && echo "Done. Run 'make bench-32'." || (echo "Failed (need write access to $(CGPATH))" && exit 1)

set-filter-64:
	@echo "Setting 64-field + flush filter on $(CGPATH)/memory.stat.ks and memory.numa_stat.ks ..."
	@echo "$(FULL_FILTER_64)" > $(CGPATH)/memory.stat.ks && echo "$(FULL_FILTER_64)" > $(CGPATH)/memory.numa_stat.ks && echo "Done. Run 'make bench-64'." || (echo "Failed (need write access to $(CGPATH))" && exit 1)

set-full-filter:
	@echo "Setting 128-field + flush filter on $(CGPATH)/memory.stat.ks and memory.numa_stat.ks ..."
	@echo "$(FULL_FILTER)" > $(CGPATH)/memory.stat.ks && echo "$(FULL_FILTER)" > $(CGPATH)/memory.numa_stat.ks && echo "Done. Run 'make bench-full'." || (echo "Failed (need write access to $(CGPATH))" && exit 1)

# Run both: full (memory.stat) vs 3-field .ks (CGPATH from Makefile, so set-filter and programs use same path)
bench: all
	@echo "=== memory.stat + memory.numa_stat (full, legacy) ==="
	@CGPATH="$(CGPATH)" time ./read_memory_stats_open_once
	@echo ""
	@echo "=== memory.stat.ks + memory.numa_stat.ks (3-field filter) ==="
	@CGPATH="$(CGPATH)" time ./read_memory_stats_ks_open_once
	@echo ""
	@echo "Done. Compare 'real' time above."

# Run: full legacy vs N-field .ks with flush (set filter then open-once + 1M reads)
bench-16: all
	@echo "=== memory.stat + memory.numa_stat (full, legacy, with flush) ==="
	@CGPATH="$(CGPATH)" time ./read_memory_stats_open_once
	@$(MAKE) set-filter-16
	@echo "=== memory.stat.ks + memory.numa_stat.ks (16-field + flush) ==="
	@CGPATH="$(CGPATH)" time ./read_memory_stats_ks_open_once
	@echo "Done. Compare 'real' time above."

bench-32: all
	@echo "=== memory.stat + memory.numa_stat (full, legacy, with flush) ==="
	@CGPATH="$(CGPATH)" time ./read_memory_stats_open_once
	@$(MAKE) set-filter-32
	@echo "=== memory.stat.ks + memory.numa_stat.ks (32-field + flush) ==="
	@CGPATH="$(CGPATH)" time ./read_memory_stats_ks_open_once
	@echo "Done. Compare 'real' time above."

bench-64: all
	@echo "=== memory.stat + memory.numa_stat (full, legacy, with flush) ==="
	@CGPATH="$(CGPATH)" time ./read_memory_stats_open_once
	@$(MAKE) set-filter-64
	@echo "=== memory.stat.ks + memory.numa_stat.ks (64-field + flush) ==="
	@CGPATH="$(CGPATH)" time ./read_memory_stats_ks_open_once
	@echo "Done. Compare 'real' time above."

bench-full: all
	@echo "=== memory.stat + memory.numa_stat (full, legacy, with flush) ==="
	@CGPATH="$(CGPATH)" time ./read_memory_stats_open_once
	@$(MAKE) set-full-filter
	@echo "=== memory.stat.ks + memory.numa_stat.ks (128-field + flush) ==="
	@CGPATH="$(CGPATH)" time ./read_memory_stats_ks_open_once
	@echo "Done. Compare 'real' time above."

clean:
	rm -f $(PROGS)

.PHONY: all set-filter set-filter-16 set-filter-32 set-filter-64 set-full-filter bench bench-16 bench-32 bench-64 bench-full clean
