#!/bin/bash
# 对比 RSTAT 和 Atomic Counter 的性能

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TEST_PARAM=${1:-1000000}
ITERATIONS=${2:-5}
OUTPUT_DIR="comparison_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "=== RSTAT vs Atomic Counter 性能对比 ==="
echo "测试参数: $TEST_PARAM"
echo "Test iterations: $ITERATIONS"
echo "结果目录: $OUTPUT_DIR"
echo ""

# 检查工具
command -v perf >/dev/null 2>&1 || { echo "Error: perf is required"; exit 1; }

# 检查当前内核配置
echo "检查内核配置..."
if grep -q "CONFIG_MEMCG_RSTAT_COUNTER=y" /boot/config-$(uname -r) 2>/dev/null; then
    CURRENT_MODE="RSTAT"
    echo "当前模式: RSTAT"
elif grep -q "CONFIG_MEMCG_ATOMIC_COUNTER=y" /boot/config-$(uname -r) 2>/dev/null; then
    CURRENT_MODE="ATOMIC"
    echo "当前模式: ATOMIC"
else
    echo "警告: 无法确定当前模式，继续测试..."
    CURRENT_MODE="UNKNOWN"
fi

echo ""
echo "注意: 需要分别编译两种内核版本进行对比"
echo "当前测试的是: $CURRENT_MODE 模式"
echo ""

# 收集性能数据
echo "Collecting performance data ($ITERATIONS iterations)..."
for i in $(seq 1 $ITERATIONS); do
    echo "  Iteration $i/$ITERATIONS..."
    
    # CPU 周期和指令
    sudo perf stat -r 1 -e cycles,instructions \
        ./readstats "$TEST_PARAM" 2>&1 | \
        grep -E "cycles|instructions" >> "$OUTPUT_DIR/cycles_instructions.txt"
    
    # Cache 性能
    sudo perf stat -r 1 -e cache-misses,cache-references,L1-dcache-load-misses,LLC-load-misses \
        ./readstats "$TEST_PARAM" 2>&1 | \
        grep -E "cache|L1|LLC" >> "$OUTPUT_DIR/cache_stats.txt"
    
    # 执行时间
    /usr/bin/time -f "%e %U %S" -o "$OUTPUT_DIR/time_$i.txt" \
        ./readstats "$TEST_PARAM" >/dev/null 2>&1
done

# 分析结果
echo ""
echo "分析结果..."

# 计算平均值
{
    echo "=== 执行时间统计 (秒) ==="
    echo "Real    User    System"
    awk '{r+=$1; u+=$2; s+=$3} END {printf "%.3f  %.3f  %.3f\n", r/NR, u/NR, s/NR}' "$OUTPUT_DIR"/time_*.txt
    echo ""
    echo "=== CPU 周期统计 ==="
    grep "cycles" "$OUTPUT_DIR/cycles_instructions.txt" | \
        awk '{sum+=$1; count++} END {if(count>0) printf "平均: %.0f cycles\n", sum/count}'
    echo ""
    echo "=== 指令统计 ==="
    grep "instructions" "$OUTPUT_DIR/cycles_instructions.txt" | \
        awk '{sum+=$1; count++} END {if(count>0) printf "平均: %.0f instructions\n", sum/count}'
    echo ""
    echo "=== Cache Miss 统计 ==="
    grep "cache-misses" "$OUTPUT_DIR/cache_stats.txt" | \
        awk '{sum+=$1; count++} END {if(count>0) printf "平均: %.0f misses\n", sum/count}'
} > "$OUTPUT_DIR/summary.txt"

# 生成详细对比报告
{
    echo "=== 性能对比报告 ==="
    echo "模式: $CURRENT_MODE"
    echo "测试参数: $TEST_PARAM"
    echo "Test iterations: $ITERATIONS"
    echo ""
    cat "$OUTPUT_DIR/summary.txt"
    echo ""
    echo "=== 详细数据 ==="
    echo ""
    echo "--- 执行时间 ---"
    cat "$OUTPUT_DIR"/time_*.txt
    echo ""
    echo "--- CPU 周期和指令 ---"
    cat "$OUTPUT_DIR/cycles_instructions.txt"
    echo ""
    echo "--- Cache 统计 ---"
    cat "$OUTPUT_DIR/cache_stats.txt"
} > "$OUTPUT_DIR/full_report.txt"

echo ""
echo "=== 对比完成 ==="
echo "Results saved in: $OUTPUT_DIR"
echo ""
echo "View summary:"
echo "  cat $OUTPUT_DIR/summary.txt"
echo ""
echo "View full report:"
echo "  cat $OUTPUT_DIR/full_report.txt"
echo ""
echo "Tip: For complete comparison:"
echo "  1. 编译 RSTAT 版本内核，运行此脚本，保存结果"
echo "  2. 编译 Atomic Counter 版本内核，运行此脚本，保存结果"
echo "  3. 对比两个结果目录的 summary.txt"


