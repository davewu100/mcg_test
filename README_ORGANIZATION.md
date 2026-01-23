# 文件整理说明

本文档说明了项目文件的组织结构。

## 目录结构

```
cgroup_test/
├── cgroup_read_test/          # 基础读取测试套件
│   ├── setup.sh               # 主设置脚本
│   ├── read.sh                # 读取测试脚本
│   ├── setup_mem.sh           # cgroup 内存设置
│   ├── mem_cgexec.sh          # cgroup 进程启动
│   ├── alloc.c                # 内存分配工具源码
│   ├── readstats.c            # 读取统计信息工具源码
│   ├── Makefile               # 编译配置
│   └── README.md              # 使用说明
│
├── binary_read_test/          # 二进制格式读取测试
│   ├── read_binary_stats.sh   # 读取二进制统计信息（stat_bin + numa_stat_bin）
│   ├── read_stat_bin.sh       # 读取单个 stat_bin 文件
│   ├── read_memory_stats_shell.sh  # Shell 方式读取内存统计
│   └── test_read_bin.sh       # 二进制文件读取测试
│
├── performance_comparison/    # 性能对比测试
│   ├── compare_realistic.sh           # 现实场景对比
│   ├── compare_realistic_60sec.sh     # 60秒现实场景对比
│   ├── compare_realistic_stable.sh     # 稳定现实场景对比
│   ├── compare_rstat_vs_atomic.sh      # RSTAT vs Atomic 对比
│   ├── compare_shell_methods.sh        # Shell 方法对比
│   └── performance_test.sh             # 性能测试
│
├── analysis_tools/            # 分析工具
│   ├── analyze_kernel_perf.sh      # 内核性能分析
│   ├── analyze_perf_results.sh     # 性能结果分析
│   └── trace_memcg_functions.sh    # 内存 cgroup 函数追踪
│
├── test_scripts/              # 其他测试脚本
│   ├── launch_workers_interval.sh   # 间隔启动工作进程
│   ├── quick_test.sh                # 快速测试
│   └── test_read_mem_stat.sh        # 读取内存统计测试
│
├── source_code/               # 源代码文件
│   ├── readstat_bin.c              # 读取单个 stat_bin
│   ├── readstats_bin.c             # 读取 stat_bin + numa_stat_bin
│   ├── readstats_interval.c         # 间隔读取统计
│   ├── readstats_light.c            # 轻量级读取
│   ├── readstats_new.c              # 新版读取
│   ├── readstats_realistic.c        # 现实场景读取
│   ├── simple_read_bin.c            # 简单二进制读取
│   └── test_concurrent_access.c     # 并发访问测试
│
└── 文档/
    ├── README_BIN_TEST.md           # 二进制测试说明
    ├── QUICK_START.md               # 快速开始指南
    └── performance_analysis_guide.md # 性能分析指南
```

## 已删除的文件

### 重复文件（已在 cgroup_read_test 中）
- `alloc.c`
- `mem_cgexec.sh`
- `read.sh`
- `readstats.c`
- `setup_mem.sh`
- `setup.sh`

### 二进制可执行文件
- `readstats_interval`
- `readstats_realistic`

### 功能重复的脚本
- `read_bin.sh` (功能被 `read_bin_updated.sh` 覆盖，已重命名为 `read_binary_stats.sh`)

### 空文件
- `shell_fastest.sh`
- `shell_optimized.sh`
- `shell_readstats_equivalent.sh`
- `test_optimization.sh`
- `test_optimized.sh`
- `compare_methods.sh`

## 文件重命名

为了更清晰地表达功能，以下文件已重命名：

- `read_bin_updated.sh` → `read_binary_stats.sh` (读取二进制统计信息)
- `readstat_bin.sh` → `read_stat_bin.sh` (读取单个 stat_bin)
- `read_mcg_million_times.sh` → `read_memory_stats_shell.sh` (Shell 方式读取)
- `mem_cgexec_interval.sh` → `launch_workers_interval.sh` (间隔启动工作进程)

## 使用建议

1. **基础测试**: 使用 `cgroup_read_test/` 目录中的文件
2. **二进制格式测试**: 使用 `binary_read_test/` 目录中的脚本
3. **性能对比**: 使用 `performance_comparison/` 目录中的脚本
4. **性能分析**: 使用 `analysis_tools/` 目录中的工具
5. **源代码**: 查看 `source_code/` 目录了解实现细节


