#!/bin/bash
# 内核性能分析脚本 - 分析 readstats 执行时的内核态性能消耗

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TEST_PARAM=${1:-1000000}
OUTPUT_DIR="perf_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "=== 内核性能分析 ==="
echo "测试参数: $TEST_PARAM"
echo "结果目录: $OUTPUT_DIR"
echo ""

# 检查工具
command -v perf >/dev/null 2>&1 || { echo "Error: perf is required"; exit 1; }

# 1. 基础性能统计
echo "[1/6] 收集基础性能统计..."
sudo perf stat -e cycles,instructions,cache-misses,cache-references,page-faults,branch-misses \
    -o "$OUTPUT_DIR/perf_stat.txt" \
    ./readstats "$TEST_PARAM" 2>&1 | tee "$OUTPUT_DIR/readstats_output.txt"

# 2. 详细函数调用分析
echo ""
echo "[2/6] 分析函数调用栈..."
sudo perf record -g -F 99 --call-graph dwarf \
    -o "$OUTPUT_DIR/perf.data" \
    ./readstats "$TEST_PARAM" >/dev/null 2>&1

# 3. 生成报告
echo "[3/6] 生成性能报告..."
sudo perf report --stdio -i "$OUTPUT_DIR/perf.data" > "$OUTPUT_DIR/perf_report.txt" 2>&1

# 4. 分析内核态函数
echo "[4/6] 分析内核态函数..."
# Filter kernel functions from the report (--kernel option doesn't exist, use grep instead)
sudo perf report --stdio -i "$OUTPUT_DIR/perf.data" 2>&1 | \
    grep -E "^[[:space:]]*[0-9]+\.[0-9]+%|\[k\]|\[kernel\]" > "$OUTPUT_DIR/perf_kernel.txt" || \
    sudo perf report --stdio -i "$OUTPUT_DIR/perf.data" 2>&1 | \
    grep -v "^#" | grep -v "^$" | head -100 > "$OUTPUT_DIR/perf_kernel.txt"

# 5. 提取热点函数
echo "[5/6] 提取热点函数..."
{
    echo "=== Top 20 热点函数 ==="
    grep -A 25 "^# Overhead" "$OUTPUT_DIR/perf_report.txt" | head -30
    echo ""
    echo "=== RSTAT 相关函数 ==="
    grep -i "rstat\|memcg_rstat" "$OUTPUT_DIR/perf_report.txt" | head -20
    echo ""
    echo "=== Atomic Counter 相关函数 ==="
    grep -i "atomic\|memcg_atomic" "$OUTPUT_DIR/perf_report.txt" | head -20
    echo ""
    echo "=== 树遍历相关函数 ==="
    grep -i "walk\|traverse\|visit" "$OUTPUT_DIR/perf_report.txt" | head -20
    echo ""
    echo "=== memory.stat 相关函数 ==="
    grep -i "memory_stat\|memcg_page_state" "$OUTPUT_DIR/perf_report.txt" | head -20
} > "$OUTPUT_DIR/hotspots.txt"

# 6. 分析特定函数
echo "[6/6] 分析特定函数..."
{
    echo "=== memcg_rstat_flush 分析 ==="
    sudo perf annotate -s memcg_rstat_flush -i "$OUTPUT_DIR/perf.data" 2>&1 | head -50 || echo "函数未找到或未采样到"
    echo ""
    echo "=== memcg_atomic_walk 分析 ==="
    sudo perf annotate -s memcg_atomic_walk -i "$OUTPUT_DIR/perf.data" 2>&1 | head -50 || echo "函数未找到或未采样到"
    echo ""
    echo "=== memcg_page_state_atomic_counter_recursive 分析 ==="
    sudo perf annotate -s memcg_page_state_atomic_counter_recursive -i "$OUTPUT_DIR/perf.data" 2>&1 | head -50 || echo "函数未找到或未采样到"
} > "$OUTPUT_DIR/annotate.txt" 2>&1

echo ""
echo "=== 分析完成 ==="
echo "Results saved in: $OUTPUT_DIR"
echo ""
echo "主要文件:"
echo "  - perf_stat.txt: 基础性能统计"
echo "  - perf_report.txt: 完整性能报告"
echo "  - perf_kernel.txt: 内核态函数报告"
echo "  - hotspots.txt: 热点函数摘要"
echo "  - annotate.txt: 热点函数汇编分析"
echo ""
echo "查看结果:"
echo "  cat $OUTPUT_DIR/hotspots.txt"
echo "  cat $OUTPUT_DIR/perf_stat.txt"


