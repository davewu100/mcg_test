# 内核性能分析指南 - RSTAT vs Atomic Counter

本指南提供详细的内核性能分析方法，用于对比 rstat 和 atomic counter 的性能消耗。

## 1. 准备工作

### 1.1 编译内核时启用调试符号
确保内核编译时包含调试符号：
```bash
# 在 .config 中设置
CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_DWARF4=y
CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y
```

### 1.2 安装性能分析工具
```bash
sudo apt-get install -y perf linux-tools-common linux-tools-generic
sudo apt-get install -y trace-cmd kernelshark
```

### 1.3 准备测试环境
```bash
cd /mnt/data/kernel/cgroup_test/mem/cgroup_test
# 确保 readstats 已编译
make readstats
```

---

## 2. 使用 Perf 进行性能分析

### 2.1 基本性能分析（CPU 时间分布）

#### 分析整个程序执行
```bash
# 记录性能数据
sudo perf record -g -F 99 --call-graph dwarf ./readstats 1000000

# 查看报告
sudo perf report --stdio > perf_report.txt
```

#### 只分析内核态
```bash
# 只记录内核态函数
sudo perf record -g -F 99 --call-graph dwarf -k 1 ./readstats 1000000

# 查看内核函数调用栈
sudo perf report --stdio --kernel > perf_kernel_report.txt
```

### 2.2 对比 RSTAT 和 Atomic Counter

#### 方法1：分别测试两种实现
```bash
# 测试 RSTAT 版本（需要重新编译内核，启用 CONFIG_MEMCG_RSTAT_COUNTER）
sudo perf record -g -F 99 --call-graph dwarf ./readstats 1000000
sudo perf report --stdio > perf_rstat.txt

# 测试 Atomic Counter 版本（启用 CONFIG_MEMCG_ATOMIC_COUNTER）
sudo perf record -g -F 99 --call-graph dwarf ./readstats 1000000
sudo perf report --stdio > perf_atomic.txt

# 对比分析
diff perf_rstat.txt perf_atomic.txt
```

#### 方法2：使用 perf stat 对比总体性能
```bash
# RSTAT 版本
sudo perf stat -e cycles,instructions,cache-misses,cache-references,page-faults ./readstats 1000000 > perf_stat_rstat.txt 2>&1

# Atomic Counter 版本
sudo perf stat -e cycles,instructions,cache-misses,cache-references,page-faults ./readstats 1000000 > perf_stat_atomic.txt 2>&1
```

### 2.3 分析特定函数

#### 分析 memory.stat 读取路径
```bash
# 记录并过滤特定函数
sudo perf record -g -F 99 --call-graph dwarf \
  -e 'probe:memory_stat_show' \
  ./readstats 1000000

# 或者使用函数过滤器
sudo perf record -g -F 99 --call-graph dwarf \
  --filter 'memory_stat_show' \
  ./readstats 1000000
```

#### 分析关键函数调用
```bash
# 分析 rstat 相关函数
sudo perf record -g -F 99 --call-graph dwarf \
  -e 'probe:memcg_rstat_updated,probe:memcg_rstat_flush,probe:memcg_page_state' \
  ./readstats 1000000

# 分析 atomic counter 相关函数
sudo perf record -g -F 99 --call-graph dwarf \
  -e 'probe:memcg_page_state_atomic_counter_recursive,probe:memcg_atomic_walk' \
  ./readstats 1000000
```

### 2.4 使用 perf annotate 查看热点代码
```bash
# 先记录
sudo perf record -g -F 99 ./readstats 1000000

# 查看特定函数的汇编代码和热点
sudo perf annotate -s memcg_page_state_atomic_counter_recursive
sudo perf annotate -s memcg_rstat_flush
```

---

## 3. 使用 Ftrace 进行函数跟踪

### 3.1 启用 ftrace
```bash
# 挂载 debugfs（如果未挂载）
sudo mount -t debugfs none /sys/kernel/debug

# 启用函数跟踪
echo function > /sys/kernel/debug/tracing/current_tracer
echo 1 > /sys/kernel/debug/tracing/tracing_on
```

### 3.2 跟踪特定函数

#### 跟踪 RSTAT 相关函数
```bash
# 设置要跟踪的函数
echo 'memcg_rstat_updated' > /sys/kernel/debug/tracing/set_ftrace_filter
echo 'memcg_rstat_flush' >> /sys/kernel/debug/tracing/set_ftrace_filter
echo 'memcg_page_state' >> /sys/kernel/debug/tracing/set_ftrace_filter
echo 'css_rstat_flush' >> /sys/kernel/debug/tracing/set_ftrace_filter

# 启用跟踪
echo 1 > /sys/kernel/debug/tracing/tracing_on

# 运行测试
./readstats 1000000

# 停止跟踪
echo 0 > /sys/kernel/debug/tracing/tracing_on

# 查看结果
cat /sys/kernel/debug/tracing/trace > ftrace_rstat.txt
```

#### 跟踪 Atomic Counter 相关函数
```bash
# 清空之前的过滤器
echo > /sys/kernel/debug/tracing/set_ftrace_filter

# 设置 atomic counter 相关函数
echo 'memcg_page_state_atomic_counter_recursive' > /sys/kernel/debug/tracing/set_ftrace_filter
echo 'memcg_atomic_walk' >> /sys/kernel/debug/tracing/set_ftrace_filter
echo 'memcg_atomic_visit_batch' >> /sys/kernel/debug/tracing/set_ftrace_filter
echo 'memcg_page_state_atomic_counter_batch' >> /sys/kernel/debug/tracing/set_ftrace_filter
echo 'atomic64_read' >> /sys/kernel/debug/tracing/set_ftrace_filter

# 启用跟踪
echo 1 > /sys/kernel/debug/tracing/tracing_on

# 运行测试
./readstats 1000000

# 停止跟踪
echo 0 > /sys/kernel/debug/tracing/tracing_on

# 查看结果
cat /sys/kernel/debug/tracing/trace > ftrace_atomic.txt
```

### 3.3 使用 trace-cmd 进行更高级的跟踪
```bash
# 跟踪特定函数并记录时间戳
sudo trace-cmd record -p function_graph \
  -g memcg_page_state_atomic_counter_recursive \
  -g memcg_rstat_flush \
  ./readstats 1000000

# 查看结果
sudo trace-cmd report > trace_report.txt
```

---

## 4. 使用 BPF/eBPF 进行动态跟踪

### 4.1 使用 bcc 工具

#### 安装 bcc
```bash
sudo apt-get install -y bpfcc-tools
```

#### 跟踪函数执行时间
```bash
# 创建跟踪脚本 trace_memcg.sh
cat > trace_memcg.sh << 'EOF'
#!/usr/bin/env python3
from bcc import BPF
import time

bpf_text = """
#include <uapi/linux/ptrace.h>

struct key_t {
    u32 pid;
    char func[64];
};

BPF_HASH(start, u32);
BPF_HASH(duration, struct key_t, u64);

int trace_entry(struct pt_regs *ctx) {
    u32 pid = bpf_get_current_pid_tgid();
    u64 ts = bpf_ktime_get_ns();
    start.update(&pid, &ts);
    return 0;
}

int trace_return(struct pt_regs *ctx) {
    u32 pid = bpf_get_current_pid_tgid();
    u64 *tsp = start.lookup(&pid);
    if (tsp == 0) {
        return 0;
    }
    u64 delta = bpf_ktime_get_ns() - *tsp;
    struct key_t key = {};
    key.pid = pid;
    bpf_get_current_comm(&key.func, sizeof(key.func));
    duration.increment(key, delta);
    start.delete(&pid);
    return 0;
}
"""

b = BPF(text=bpf_text)
b.attach_kprobe(event="memcg_page_state_atomic_counter_recursive", fn_name="trace_entry")
b.attach_kretprobe(event="memcg_page_state_atomic_counter_recursive", fn_name="trace_return")
b.attach_kprobe(event="memcg_rstat_flush", fn_name="trace_entry")
b.attach_kretprobe(event="memcg_rstat_flush", fn_name="trace_return")

print("Tracing... Press Ctrl-C to end")
time.sleep(999999)
EOF

chmod +x trace_memcg.sh
```

---

## 5. 分析内存访问模式（Cache 性能）

### 5.1 使用 perf 分析 Cache 性能
```bash
# 分析 cache miss
sudo perf stat -e L1-dcache-loads,L1-dcache-load-misses,L1-dcache-stores \
  -e LLC-loads,LLC-load-misses,LLC-stores \
  ./readstats 1000000
```

### 5.2 分析特定函数的 Cache 行为
```bash
# 记录 cache 事件
sudo perf record -e L1-dcache-load-misses,LLC-load-misses \
  -g ./readstats 1000000

# 查看哪些函数导致 cache miss
sudo perf report --stdio --sort symbol,cache-misses
```

---

## 6. 自动化性能对比脚本

创建自动化脚本来对比两种实现：

```bash
cat > compare_performance.sh << 'EOF'
#!/bin/bash

echo "=== Performance Comparison: RSTAT vs Atomic Counter ==="
echo ""

# 测试次数
ITERATIONS=5

# 测试参数
TEST_PARAM=1000000

echo "Testing with parameter: $TEST_PARAM"
echo "Iterations: $ITERATIONS"
echo ""

# 测试 RSTAT
echo "=== Testing RSTAT ==="
for i in $(seq 1 $ITERATIONS); do
    echo "Iteration $i..."
    sudo perf stat -r 1 -e cycles,instructions,cache-misses \
        ./readstats $TEST_PARAM 2>&1 | grep -E "cycles|instructions|cache-misses" >> rstat_stats.txt
done

# 测试 Atomic Counter
echo "=== Testing Atomic Counter ==="
for i in $(seq 1 $ITERATIONS); do
    echo "Iteration $i..."
    sudo perf stat -r 1 -e cycles,instructions,cache-misses \
        ./readstats $TEST_PARAM 2>&1 | grep -E "cycles|instructions|cache-misses" >> atomic_stats.txt
done

echo ""
echo "=== Results ==="
echo "RSTAT results saved to rstat_stats.txt"
echo "Atomic Counter results saved to atomic_stats.txt"
EOF

chmod +x compare_performance.sh
```

---

## 7. 分析内核态时间分布

### 7.1 使用 perf 分析内核态 vs 用户态
```bash
# 记录内核态和用户态时间
sudo perf record -g -F 99 --call-graph dwarf \
  -e cycles:k,cycles:u \
  ./readstats 1000000

# 查看内核态时间占比
sudo perf report --stdio --sort comm,dso | head -50
```

### 7.2 分析系统调用开销
```bash
# 跟踪系统调用
sudo perf trace -e 'syscalls:sys_enter_read' \
  -e 'syscalls:sys_exit_read' \
  ./readstats 1000000 > syscall_trace.txt
```

---

## 8. 关键性能指标对比

### 8.1 创建性能分析脚本
```bash
cat > analyze_performance.sh << 'EOF'
#!/bin/bash

# 分析 perf 报告，提取关键指标
perf_file=$1

if [ -z "$perf_file" ]; then
    echo "Usage: $0 <perf_report_file>"
    exit 1
fi

echo "=== Analyzing $perf_file ==="
echo ""

# 提取热点函数
echo "Top 10 Hot Functions:"
grep -A 2 "Overhead" $perf_file | head -30

# 提取 rstat 相关函数
echo ""
echo "=== RSTAT Related Functions ==="
grep -i "rstat\|memcg_rstat" $perf_file | head -20

# 提取 atomic counter 相关函数
echo ""
echo "=== Atomic Counter Related Functions ==="
grep -i "atomic\|memcg_atomic" $perf_file | head -20

# 提取树遍历相关函数
echo ""
echo "=== Tree Traversal Functions ==="
grep -i "walk\|traverse\|visit" $perf_file | head -20
EOF

chmod +x analyze_performance.sh
```

---

## 9. 具体分析步骤

### 步骤1：基础性能测试
```bash
cd /mnt/data/kernel/cgroup_test/mem/cgroup_test

# 运行基础测试
time ./readstats 1000000

# 使用 perf stat 获取基础指标
sudo perf stat -e cycles,instructions,cache-misses,page-faults \
  ./readstats 1000000
```

### 步骤2：详细函数分析
```bash
# 记录详细调用栈
sudo perf record -g -F 99 --call-graph dwarf ./readstats 1000000

# 生成报告
sudo perf report --stdio > detailed_report.txt

# 分析报告
./analyze_performance.sh detailed_report.txt
```

### 步骤3：对比 RSTAT 和 Atomic Counter
```bash
# 运行对比脚本
./compare_performance.sh

# 手动分析差异
diff -u rstat_stats.txt atomic_stats.txt
```

### 步骤4：分析特定热点
```bash
# 如果发现某个函数是热点，详细分析
sudo perf record -g -F 99 --call-graph dwarf ./readstats 1000000
sudo perf annotate -s <function_name>
```

---

## 10. 常见性能问题诊断

### 10.1 如果发现 atomic counter 慢
- 检查是否使用了 batch 版本（应该用 batch，而不是 recursive）
- 检查树遍历次数（应该只有 1-2 次，而不是 20+ 次）
- 检查是否有不必要的 atomic64_read 调用

### 10.2 如果发现 rstat 慢
- 检查 rstat flush 频率
- 检查是否有过多的 per-CPU 更新
- 检查树遍历路径

### 10.3 如果发现 cache miss 高
- 检查数据结构布局（是否在同一 cacheline）
- 检查访问模式（是否顺序访问）
- 考虑使用 prefetch

---

## 11. 推荐的分析流程

1. **快速概览**：使用 `perf stat` 获取总体性能指标
2. **热点识别**：使用 `perf record + perf report` 找出热点函数
3. **详细分析**：使用 `perf annotate` 分析热点函数的汇编代码
4. **对比测试**：分别测试 RSTAT 和 Atomic Counter，对比结果
5. **深度分析**：使用 ftrace 或 eBPF 进行更细粒度的分析

---

## 12. 示例输出解读

### perf report 输出示例
```
# Overhead  Command      Shared Object     Symbol
# ........  .......  ................  .....................
    45.23%  readstats  [kernel.kallsyms]  [k] memcg_rstat_flush
    23.45%  readstats  [kernel.kallsyms]  [k] memcg_atomic_walk
    12.34%  readstats  [kernel.kallsyms]  [k] atomic64_read
```

解读：
- `memcg_rstat_flush` 占用 45.23% 的时间（RSTAT 版本）
- `memcg_atomic_walk` 占用 23.45% 的时间（Atomic Counter 版本）
- `atomic64_read` 占用 12.34% 的时间（读取开销）

---

## 13. 注意事项

1. **权限要求**：大部分性能分析工具需要 root 权限
2. **性能影响**：性能分析工具本身会带来开销，可能影响结果
3. **多次测试**：建议多次运行取平均值
4. **环境一致性**：确保测试环境一致（CPU 频率、负载等）
5. **内核版本**：确保分析的内核版本与运行版本一致


