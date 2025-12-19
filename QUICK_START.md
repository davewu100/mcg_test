# 性能分析快速开始指南

## 快速开始

### 1. 基础性能分析（推荐首先运行）

```bash
cd /mnt/data/kernel/cgroup_test/mem/cgroup_test
./analyze_kernel_perf.sh 1000000
```

这会生成完整的性能分析报告，包括：
- 基础性能统计（CPU周期、指令、cache miss等）
- 函数调用栈分析
- 热点函数识别
- 内核态函数分析

**查看结果：**
```bash
cat perf_results_*/hotspots.txt
cat perf_results_*/perf_stat.txt
```

---

### 2. 对比 RSTAT vs Atomic Counter

**注意：** 需要分别编译两种内核版本

```bash
# 在 RSTAT 内核版本下运行
./compare_rstat_vs_atomic.sh 1000000 5

# 切换到 Atomic Counter 内核版本，再次运行
./compare_rstat_vs_atomic.sh 1000000 5

# 对比结果
diff comparison_*/summary.txt
```

---

### 3. 使用 Ftrace 跟踪特定函数

```bash
# 跟踪 Atomic Counter 相关函数
./trace_memcg_functions.sh 1000000 atomic

# 跟踪 RSTAT 相关函数
./trace_memcg_functions.sh 1000000 rstat
```

**查看结果：**
```bash
less ftrace_results_*/ftrace_atomic.txt
cat ftrace_results_*/analysis.txt
```

---

## 常用命令

### 快速查看性能
```bash
# 基础统计
sudo perf stat ./readstats 1000000

# 查看热点函数
sudo perf record -g ./readstats 1000000
sudo perf report
```

### 分析特定函数
```bash
# 记录性能数据
sudo perf record -g ./readstats 1000000

# 查看特定函数的汇编代码
sudo perf annotate -s memcg_atomic_walk
sudo perf annotate -s memcg_rstat_flush
```

### 分析 Cache 性能
```bash
sudo perf stat -e L1-dcache-load-misses,LLC-load-misses \
    ./readstats 1000000
```

---

## 关键性能指标解读

### perf stat 输出解读

```
 Performance counter stats for './readstats 1000000':

         10,234,567,890      cycles                    #    3.500 GHz
         15,123,456,789      instructions              #    1.48  insn per cycle
          1,234,567         cache-misses              #    0.012 % of all cache refs
         10,234,567,890      cache-references
            123,456         page-faults               #    0.123 K/sec
```

- **cycles**: CPU周期数，越低越好
- **instructions**: 指令数，越低越好
- **cache-misses**: Cache未命中次数，越低越好
- **insn per cycle (IPC)**: 每周期指令数，越高越好（通常 1-4）

### perf report 输出解读

```
# Overhead  Command      Shared Object     Symbol
# ........  .......  ................  .....................
    45.23%  readstats  [kernel.kallsyms]  [k] memcg_rstat_flush
    23.45%  readstats  [kernel.kallsyms]  [k] memcg_atomic_walk
```

- **Overhead**: 该函数占用的时间百分比
- **Symbol**: 函数名
- 百分比越高，说明该函数是性能瓶颈

---

## 性能分析检查清单

### 对于 Atomic Counter：
- [ ] 是否使用了 batch 版本？（应该用 batch，不是 recursive）
- [ ] 树遍历次数是多少？（应该只有 1-2 次）
- [ ] Events 是否使用了 batch？（避免 20 次树遍历）
- [ ] atomic64_read 调用次数是否过多？

### 对于 RSTAT：
- [ ] rstat flush 频率是多少？
- [ ] 是否有过多的 per-CPU 更新？
- [ ] 树遍历路径是否优化？

### 通用检查：
- [ ] Cache miss 率是否过高？
- [ ] 是否有不必要的锁竞争？
- [ ] 数据结构是否 cacheline 对齐？

---

## 常见问题

### Q: perf 报告显示 "no symbols found"
**A:** 需要确保内核编译时启用了调试符号：
```bash
CONFIG_DEBUG_INFO=y
CONFIG_KALLSYMS=y
```

### Q: ftrace 无法访问 /sys/kernel/debug/tracing
**A:** 需要挂载 debugfs：
```bash
sudo mount -t debugfs none /sys/kernel/debug
```

### Q: 如何确定当前使用的是 RSTAT 还是 Atomic Counter？
**A:** 检查内核配置：
```bash
grep MEMCG /boot/config-$(uname -r) | grep COUNTER
```

### Q: 性能分析工具本身影响结果怎么办？
**A:** 
- 使用 `perf stat` 而不是 `perf record`（开销更小）
- 多次运行取平均值
- 对比测试时保持环境一致

---

## 下一步

1. 运行 `./analyze_kernel_perf.sh` 获取基础分析
2. 查看 `hotspots.txt` 找出性能瓶颈
3. 使用 `perf annotate` 分析热点函数
4. 对比 RSTAT 和 Atomic Counter 的结果
5. 根据分析结果进行优化

详细文档请参考：`performance_analysis_guide.md`


