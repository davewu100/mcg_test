#!/bin/bash
# 现实场景性能对比脚本
# 使用 readstats_realistic 模拟实际使用模式：指定时间段内的读取频率

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 默认参数
DURATION=${1:-10}          # 模拟持续时间（秒）
READS_PER_SEC=${2:-1}      # Reads per second
ITERATIONS=${3:-5}         # Test iterations
OUTPUT_DIR="realistic_comparison_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "=== 现实场景性能对比 ==="
echo "模拟时长: ${DURATION}秒"
echo "Read frequency: ${READS_PER_SEC} reads/second"
echo "总读取数: $((DURATION * READS_PER_SEC))"
echo "Test iterations: ${ITERATIONS}"
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
echo "Note: This test simulates real scenario - performs $((DURATION * READS_PER_SEC)) reads within ${DURATION} seconds"
echo "      但所有读取连续执行，无等待时间，用于快速性能对比"
echo ""

# 执行测试
echo "Running performance test (${ITERATIONS} iterations)..."
for i in $(seq 1 $ITERATIONS); do
    echo "  Iteration $i/${ITERATIONS}..."

    # 使用 perf 收集详细性能数据
    perf stat -r 1 -e cycles,instructions,cache-misses,cache-references,L1-dcache-load-misses,LLC-load-misses \
        -o "$OUTPUT_DIR/perf_stat_$i.txt" \
        ./readstats_realistic "$DURATION" "$READS_PER_SEC" >> "$OUTPUT_DIR/test_output_$i.txt" 2>&1

    # Collect average time per read from program output
    ./readstats_realistic "$DURATION" "$READS_PER_SEC" 2>/dev/null | \
        grep "Average time per read" | awk '{print $5}' > "$OUTPUT_DIR/avg_time_$i.txt"
done

# 分析结果
echo ""
echo "分析结果..."

# 提取并计算平均值
{
    echo "=== 测试配置 ==="
    echo "模拟时长: ${DURATION}秒"
    echo "Read frequency: ${READS_PER_SEC} reads/second"
    echo "总读取数: $((DURATION * READS_PER_SEC))"
    echo "Test iterations: ${ITERATIONS}"
    echo "内核模式: $CURRENT_MODE"
    echo ""

    echo "=== Average Time Per Read ==="
    echo "Average time per read:"
    awk '{r+=$1; count++} END {if(count>0) printf "%.2f microseconds (average)\n", r/count; else print "No data"}' "$OUTPUT_DIR"/avg_time_*.txt
    echo ""
    echo "=== 执行时间统计 (秒) ==="
    echo "Total execution time:"
    awk '{r+=$1; count++} END {if(count>0) printf "%.6f seconds (average)\n", r/count; else print "No data"}' "$OUTPUT_DIR"/time_*.txt
    echo ""

    echo "=== CPU 性能统计 ==="
    echo "平均 CPU 周期:"
    grep "cycles/u" "$OUTPUT_DIR"/perf_stat_*.txt | \
        grep -v "<not counted>" | \
        awk '{gsub(/,/,"",$2); sum+=$2; count++} END {if(count>0) printf "  %.0f cycles\n", sum/count}'

    echo "平均指令数:"
    grep "instructions/u" "$OUTPUT_DIR"/perf_stat_*.txt | \
        grep -v "<not counted>" | \
        awk '{gsub(/,/,"",$2); sum+=$2; count++} END {if(count>0) printf "  %.0f instructions\n", sum/count}'

    echo "平均 Cache Miss:"
    grep "cache-misses/u" "$OUTPUT_DIR"/perf_stat_*.txt | \
        grep -v "<not counted>" | \
        awk '{gsub(/,/,"",$2); sum+=$2; count++} END {if(count>0) printf "  %.0f misses\n", sum/count}'

    echo "执行时间 (从perf):"
    grep "seconds time elapsed" "$OUTPUT_DIR"/perf_stat_*.txt | \
        awk '{sum+=$1; count++} END {if(count>0) printf "  %.6f seconds (average)\n", sum/count}'
    echo ""

    echo "=== 实际场景对比 ==="
    echo "此测试模拟了实际监控场景："
    echo "  - 监控时长: ${DURATION}秒"
    echo "  • Sampling frequency: ${READS_PER_SEC} reads/second"
    echo "  - 总采样数: $((DURATION * READS_PER_SEC))"
    echo ""
    echo "实际应用中，这些读取会分散在 ${DURATION}秒内，"
    echo "但测试中连续执行以快速获得性能对比数据。"

} > "$OUTPUT_DIR/summary.txt"

# 生成完整报告
{
    echo "=== 现实场景性能测试报告 ==="
    echo "生成时间: $(date)"
    echo ""
    cat "$OUTPUT_DIR/summary.txt"
    echo ""
    echo "=== 详细性能数据 ==="
    echo ""
    echo "--- Execution time per iteration ---"
    for i in $(seq 1 $ITERATIONS); do
        echo "Iteration $i: $(cat "$OUTPUT_DIR/time_$i.txt")"
    done
    echo ""
    echo "--- Perf 统计数据 ---"
    cat "$OUTPUT_DIR"/perf_stat_*.txt
    echo ""
    echo "--- 测试程序输出 ---"
    cat "$OUTPUT_DIR"/test_output_*.txt
} > "$OUTPUT_DIR/full_report.txt"

echo ""
echo "=== Test Completed ==="
echo "Results saved in: $OUTPUT_DIR"
echo ""
echo "View summary:"
echo "  cat $OUTPUT_DIR/summary.txt"
echo ""
echo "View full report:"
echo "  cat $OUTPUT_DIR/full_report.txt"
echo ""
echo "Tip: For complete RSTAT vs Atomic Counter comparison:"
echo "  1. 在 RSTAT 内核上运行: ./compare_realistic.sh 10 1"
echo "  2. 在 Atomic Counter 内核上运行: ./compare_realistic.sh 10 1"
echo "  3. 对比两个结果目录的 summary.txt"
