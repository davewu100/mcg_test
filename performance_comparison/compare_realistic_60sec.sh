#!/bin/bash
# Realistic 60-second performance comparison test - actually runs for 60 seconds, 1 read per second

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 默认参数 - 真实的60秒测试
READS_COUNT=${1:-60}       # Read count (default 60)
INTERVAL_MS=${2:-1000}     # 间隔时间（默认1000ms=1秒）
ITERATIONS=${3:-3}         # Test iterations
OUTPUT_DIR="realistic_60sec_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "=== Realistic 60-Second Performance Comparison Test ==="
echo "⏱️  Test Configuration:"
echo "  Total reads per iteration: ${READS_COUNT}"
echo "  Read interval: ${INTERVAL_MS}ms"
echo "  Expected total time: $((READS_COUNT * INTERVAL_MS / 1000)) seconds"
echo "  Test iterations: ${ITERATIONS}"
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
echo "🎯 Execution Strategy:"
echo "  • Each iteration: ${READS_COUNT} reads with ${INTERVAL_MS}ms intervals"
echo "  • Single iteration duration: $((READS_COUNT * INTERVAL_MS / 1000)) seconds"
echo "  • Fully simulates real monitoring scenario read frequency"
echo "  • ${ITERATIONS} iterations for statistical stability"
echo ""

# 执行测试
echo "Running realistic monitoring test (${ITERATIONS} iterations)..."
echo "Note: Each iteration will take approximately $((READS_COUNT * INTERVAL_MS / 1000)) seconds..."
echo ""

for i in $(seq 1 $ITERATIONS); do
    echo "▶️  Starting iteration $i/${ITERATIONS} (will take ~$((READS_COUNT * INTERVAL_MS / 1000)) seconds)..."

    # 记录开始时间
    start_time=$(date +%s)

    # 使用 perf 收集详细性能数据 - 真实的间隔执行
    perf stat -r 1 -e cycles,instructions,cache-misses,cache-references,L1-dcache-load-misses,LLC-load-misses \
        -o "$OUTPUT_DIR/perf_stat_$i.txt" \
        ./readstats_interval "$READS_COUNT" "$INTERVAL_MS" >> "$OUTPUT_DIR/test_output_$i.txt" 2>&1

    # 记录结束时间
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    echo "✅ Iteration $i completed, took ${duration} seconds"
    echo ""
done

# 分析结果
echo ""
echo "📊 Analyzing results..."

# 计算统计信息
{
    echo "=== Test Configuration ==="
    echo "Total reads per iteration: ${READS_COUNT}"
    echo "Read interval: ${INTERVAL_MS}ms"
    echo "Expected single iteration time: $((READS_COUNT * INTERVAL_MS / 1000)) seconds"
    echo "Test iterations: ${ITERATIONS}"
    echo "Kernel mode: $CURRENT_MODE"
    echo ""

    echo "=== Performance Statistics (Average) ==="

    # CPU 周期
    echo "Average CPU cycles:"
    grep "cycles" "$OUTPUT_DIR"/perf_stat_*.txt | \
        grep -v "<not counted>" | head -${ITERATIONS} | \
        awk '{val = ($1 ~ /:/) ? $3 : $1; gsub(/,/,"",val); sum+=val; count++} END {if(count>0) printf "  %.0f cycles/iteration\n", sum/count}'

    # 指令数
    echo "Average instructions:"
    grep "instructions" "$OUTPUT_DIR"/perf_stat_*.txt | \
        grep -v "<not counted>" | head -${ITERATIONS} | \
        awk '{val = ($1 ~ /:/) ? $3 : $1; gsub(/,/,"",val); sum+=val; count++} END {if(count>0) printf "  %.0f instructions/iteration\n", sum/count}'

    # Cache Miss
    echo "Average cache misses:"
    grep "cache-misses" "$OUTPUT_DIR"/perf_stat_*.txt | \
        grep -v "<not counted>" | head -${ITERATIONS} | \
        awk '{val = ($1 ~ /:/) ? $3 : $1; gsub(/,/,"",val); sum+=val; count++} END {if(count>0) printf "  %.0f misses/iteration\n", sum/count}'

    # 执行时间
    echo "Average execution time:"
    grep "seconds time elapsed" "$OUTPUT_DIR"/perf_stat_*.txt | \
        awk '{sum+=$1; count++} END {if(count>0) printf "  %.2f seconds/iteration\n", sum/count}'

    echo ""
    echo "=== Real Scenario Simulation ==="
    echo "This test fully simulates a real monitoring scenario:"
    echo "  • Monitoring duration: $((READS_COUNT * INTERVAL_MS / 1000)) seconds"
    echo "  • Sampling frequency: $((1000 / INTERVAL_MS)) reads/second"
    echo "  • Total samples: ${READS_COUNT}"
    echo ""
    echo "Test results can be directly used to evaluate performance in actual applications."

} > "$OUTPUT_DIR/summary.txt"

echo ""
echo "=== Test Completed ==="
echo "Results saved in: $OUTPUT_DIR"
echo ""
echo "View summary:"
echo "  cat $OUTPUT_DIR/summary.txt"
echo ""
echo "View detailed output:"
echo "  cat $OUTPUT_DIR/test_output_*.txt | head -20"
echo ""
echo "💡 Tip: This test fully simulates a real monitoring scenario, takes longer but provides more realistic results"
