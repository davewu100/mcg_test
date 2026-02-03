# Why two benchmarks differ, and which is more accurate

## 1. Why does Make need sudo?

**Before:** The Makefile used `sudo tee` to write the filter to `/sys/fs/cgroup/memory.stat.ks`. The root cgroup is usually writable only by root, so `set-filter` needed sudo.

**Now:** The Makefile uses plain `echo ... > $(CGPATH)/...` (no sudo). So:
- If **CGPATH** is writable by you (e.g. a cgroup you own), run `make set-filter` and `make bench` **without sudo**.
- To use a cgroup you own: create it once with root, then chown to yourself:
  ```bash
  sudo mkdir -p /sys/fs/cgroup/bench && sudo chown $USER /sys/fs/cgroup/bench
  make bench CGPATH=/sys/fs/cgroup/bench
  ```
- To use the **root cgroup** (`/sys/fs/cgroup`), you still need write access: run `sudo make set-filter` (or `sudo make bench` so the filter write runs as root). The C programs read **CGPATH** from the environment; the Makefile passes `CGPATH=$(CGPATH)` when running them, so they use the same path as set-filter.

---

## 2. Why do test_memstat_btf.sh and binary_read_test give different results?

They measure **different things**.

| | test_memstat_btf.sh | binary_read_test |
|--|---------------------|------------------|
| **What each "read" is** | One `cat` = **open + read + close** | One **lseek(0) + read()** (file already open) |
| **Open/close** | 1000 or 1000 times (once per cat) | Once at start, then 1M read cycles |
| **Metric** | Time per **full `cat`** (μs per cat) | Time per **read path only** (μs per lseek+read), amortized |

So:
- **test_memstat_btf.sh** ≈ "How long does one `cat memory.stat.ks` take?" — includes **syscall overhead** (open, read, close) and **kernel read path** (flush + format + output).
- **binary_read_test** ≈ "How long is the **kernel read path** alone?" — open/close cost is amortized over 1M reads, so the number is much smaller (e.g. ~5 μs vs ~1300 μs).

That’s why:
- **Selftest**: legacy ~1315 μs/read, ks full BTF ~1745 μs/read → ks **slower** per `cat` when both flush.
- **binary_read_test**: legacy ~5 μs/read, ks 3-field ~0.85 μs/read → ks **faster** per read path.

The **ratio** (ks vs legacy) can also differ because in the selftest the **per-cat** cost is dominated by open/read/close and kernel work together; in binary_read_test the **per-read** cost is almost only the kernel read path (flush + output).

---

## 3. Which is more accurate?

Both are accurate for what they measure; it depends on **how you use the interface**.

- **If the use case is "run `cat` (or equivalent) once per query"** (e.g. a script or tool that opens, reads, closes each time):  
  **test_memstat_btf.sh** is more representative. Its "μs per read" is **μs per full cat**, so it reflects real latency for that usage. In that scenario, with both sides flushing, legacy can be faster than ks full BTF (as in your 1000-read selftest).

- **If the use case is "keep the file open and do many lseek+read in a loop"** (e.g. a daemon with one open fd):  
  **binary_read_test** is more representative. Its "μs per read" is **μs per kernel read path**, so it reflects throughput of the read path alone. There, ks 3/16/32-field can be much faster than legacy; ks 64/128-field can be slower due to more output work.

**Summary:** Use **test_memstat_btf.sh** for "one cat per query" latency; use **binary_read_test** for "many reads with one open" throughput. Neither is wrong — they answer different questions.
