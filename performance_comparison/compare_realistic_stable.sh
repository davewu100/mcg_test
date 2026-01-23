#!/bin/bash
# 稳定的现实场景性能对比脚本 - 减少波动，提高准确性

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default parameters - use fewer reads and more iterations to reduce variation
DURATION=${1:-10}          # 模拟持续时间（秒）
READS_PER_SEC=${2:-10}     # Reads per second (higher frequency reduces per-read variation)
ITERATIONS=${3:-10}        # Test iterations (more iterations improve statistical stability)
OUTPUT_DIR="stable_comparison_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "=== Stable Performance Comparison Test ==="
echo "📊 Test Configuration:"
echo "  Simulated scenario duration: ${DURATION} seconds"
echo "  Read frequency: ${READS_PER_SEC} reads/second"
echo "  Reads per iteration: $((DURATION * READS_PER_SEC))"
echo "  Test iterations: ${ITERATIONS}"
echo "  Total reads: $((DURATION * READS_PER_SEC * ITERATIONS))"
echo "Results directory: $OUTPUT_DIR"
echo ""

# 检查工具
command -v perf >/dev/null 2>&1 || { echo "Error: perf is required"; exit 1; }

# 检查当前内核配置
echo "Checking kernel configuration..."
if grep -q "CONFIG_MEMCG_RSTAT_COUNTER=y" /boot/config-$(uname -r) 2>/dev/null; then
    CURRENT_MODE="RSTAT"
    echo "Current mode: RSTAT"
elif grep -q "CONFIG_MEMCG_ATOMIC_COUNTER=y" /boot/config-$(uname -r) 2>/dev/null; then
    CURRENT_MODE="ATOMIC"
    echo "Current mode: ATOMIC"
else
    echo "Warning: Cannot determine current mode, continuing test..."
    CURRENT_MODE="UNKNOWN"
fi

echo ""
echo "⚡ Execution Strategy:"
echo "  • Simulate ${DURATION}-second monitoring scenario with ${READS_PER_SEC} reads/second"
echo "  • But execute reads consecutively without delays (for fast performance testing)"
echo "  • Use ${ITERATIONS} iterations to average out system noise and improve stability"
echo ""

# 执行测试
echo "Running performance test (${ITERATIONS} iterations)..."
for i in $(seq 1 $ITERATIONS); do
    echo -ne "  Iteration $i/${ITERATIONS}...\r"

    # 使用 perf 收集详细性能数据
    perf stat -r 1 -e cycles,instructions,cache-misses,cache-references,L1-dcache-load-misses,LLC-load-misses \
        -o "$OUTPUT_DIR/perf_stat_$i.txt" \
        ./readstats_realistic "$DURATION" "$READS_PER_SEC" >> "$OUTPUT_DIR/test_output_$i.txt" 2>&1

    # Collect average time per read from program output
    ./readstats_realistic "$DURATION" "$READS_PER_SEC" 2>/dev/null | \
        grep "Average time per read" | awk '{print $5}' > "$OUTPUT_DIR/avg_time_$i.txt"
done
echo "" # 换行

# 分析结果
echo ""
echo "Analyzing results..."

# 计算统计信息
{
    echo "=== Test Configuration ==="
    echo "Simulated duration: ${DURATION} seconds"
    echo "Read frequency: ${READS_PER_SEC} reads/second"
    echo "Total reads per iteration: $((DURATION * READS_PER_SEC))"
    echo "Test iterations: ${ITERATIONS}"
    echo "Kernel mode: $CURRENT_MODE"
    echo ""

    # Calculate average time per read
    echo "=== Average Time Per Read Statistics ==="
    echo "Mean:"
    awk '{r+=$1; count++} END {if(count>0) printf "%.2f microseconds\n", r/count}' "$OUTPUT_DIR"/avg_time_*.txt

    echo "Standard deviation:"
    awk '{
        sum += $1;
        sumsq += $1*$1;
        count++
    } END {
        if(count>1) {
            mean = sum/count;
            variance = (sumsq/count) - (mean*mean);
            stdev = sqrt(variance);
            printf "%.2f microseconds\n", stdev;
            printf "Coefficient of variation: %.1f%%\n", (stdev/mean)*100;
        }
    }' "$OUTPUT_DIR"/avg_time_*.txt

    echo "Min-Max:"
    awk 'BEGIN {min=999999; max=0} {if($1<min) min=$1; if($1>max) max=$1} END {printf "%.2f - %.2f microseconds\n", min, max}' "$OUTPUT_DIR"/avg_time_*.txt
    echo ""

    echo "=== CPU Performance Statistics ==="
    echo "Average CPU cycles:"
    grep "cycles" "$OUTPUT_DIR"/perf_stat_*.txt | \
        grep -v "<not counted>" | \
        awk '{val = ($1 ~ /:/) ? $2 : $1; gsub(/,/,"",val); sum+=val; count++} END {if(count>0) printf "  %.0f cycles\n", sum/count}'

    echo "Average instructions:"
    grep "instructions" "$OUTPUT_DIR"/perf_stat_*.txt | \
        grep -v "<not counted>" | \
        awk '{val = ($1 ~ /:/) ? $2 : $1; gsub(/,/,"",val); sum+=val; count++} END {if(count>0) printf "  %.0f instructions\n", sum/count}'

    echo "Average cache misses:"
    grep "cache-misses" "$OUTPUT_DIR"/perf_stat_*.txt | \
        grep -v "<not counted>" | \
        awk '{val = ($1 ~ /:/) ? $2 : $1; gsub(/,/,"",val); sum+=val; count++} END {if(count>0) printf "  %.0f misses\n", sum/count}'

    echo "Execution time (from perf):"
    grep "seconds time elapsed" "$OUTPUT_DIR"/perf_stat_*.txt | \
        awk '{sum+=$1; count++} END {if(count>0) printf "  %.6f seconds (average)\n", sum/count}'

} > "$OUTPUT_DIR/summary.txt"

echo ""
echo "=== Test Completed ==="
echo "Results saved in: $OUTPUT_DIR"
echo ""
echo "View summary:"
echo "  cat $OUTPUT_DIR/summary.txt"
echo ""
echo "Tip: This method reduces variation through multiple iterations, providing more stable performance comparison"
