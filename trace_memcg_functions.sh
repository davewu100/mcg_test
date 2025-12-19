#!/bin/bash
# 使用 ftrace 跟踪 memcg 相关函数

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TEST_PARAM=${1:-1000000}
TRACE_TYPE=${2:-atomic}  # atomic 或 rstat

TRACE_DIR="/sys/kernel/debug/tracing"
OUTPUT_DIR="ftrace_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "=== Ftrace 函数跟踪 ==="
echo "测试参数: $TEST_PARAM"
echo "跟踪类型: $TRACE_TYPE"
echo "结果目录: $OUTPUT_DIR"
echo ""

# 检查 debugfs
if [ ! -d "$TRACE_DIR" ]; then
    echo "挂载 debugfs..."
    sudo mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
fi

if [ ! -d "$TRACE_DIR" ]; then
    echo "错误: 无法访问 $TRACE_DIR"
    echo "请确保内核启用了 CONFIG_DEBUG_FS"
    exit 1
fi

# 清理之前的跟踪
echo "清理之前的跟踪..."
echo 0 > "$TRACE_DIR/tracing_on" 2>/dev/null || sudo sh -c "echo 0 > $TRACE_DIR/tracing_on"
echo nop > "$TRACE_DIR/current_tracer" 2>/dev/null || sudo sh -c "echo nop > $TRACE_DIR/current_tracer"
echo > "$TRACE_DIR/set_ftrace_filter" 2>/dev/null || sudo sh -c "echo > $TRACE_DIR/set_ftrace_filter"

# 设置跟踪函数
echo "设置跟踪函数..."
if [ "$TRACE_TYPE" = "atomic" ]; then
    FUNCTIONS=(
        "memcg_page_state_atomic_counter_recursive"
        "memcg_page_state_atomic_counter_batch"
        "memcg_atomic_walk"
        "memcg_atomic_visit_batch"
        "memcg_atomic_visit_node"
        "memcg_events_atomic_counter_recursive"
        "memcg_events_atomic_counter_batch"
        "atomic64_read"
    )
    OUTPUT_FILE="$OUTPUT_DIR/ftrace_atomic.txt"
elif [ "$TRACE_TYPE" = "rstat" ]; then
    FUNCTIONS=(
        "memcg_rstat_updated"
        "memcg_rstat_flush"
        "css_rstat_flush"
        "memcg_page_state"
        "memcg_rstat_css_flush"
    )
    OUTPUT_FILE="$OUTPUT_DIR/ftrace_rstat.txt"
else
    echo "错误: 跟踪类型必须是 'atomic' 或 'rstat'"
    exit 1
fi

# 设置函数过滤器
for func in "${FUNCTIONS[@]}"; do
    echo "$func" >> "$TRACE_DIR/set_ftrace_filter" 2>/dev/null || \
        sudo sh -c "echo $func >> $TRACE_DIR/set_ftrace_filter"
done

# 使用 function_graph 跟踪器以获得更详细的信息
echo "function_graph" > "$TRACE_DIR/current_tracer" 2>/dev/null || \
    sudo sh -c "echo function_graph > $TRACE_DIR/current_tracer"

# 设置缓冲区大小
echo 16384 > "$TRACE_DIR/buffer_size_kb" 2>/dev/null || \
    sudo sh -c "echo 16384 > $TRACE_DIR/buffer_size_kb"

# 启用跟踪
echo "开始跟踪..."
echo 1 > "$TRACE_DIR/tracing_on" 2>/dev/null || \
    sudo sh -c "echo 1 > $TRACE_DIR/tracing_on"

# 运行测试
echo "运行测试程序..."
./readstats "$TEST_PARAM" >/dev/null 2>&1

# 停止跟踪
echo "停止跟踪..."
echo 0 > "$TRACE_DIR/tracing_on" 2>/dev/null || \
    sudo sh -c "echo 0 > $TRACE_DIR/tracing_on"

# 保存结果
echo "保存跟踪结果..."
cat "$TRACE_DIR/trace" > "$OUTPUT_FILE" 2>/dev/null || \
    sudo cat "$TRACE_DIR/trace" > "$OUTPUT_FILE"

# 分析结果
echo "分析跟踪结果..."
{
    echo "=== 函数调用统计 ==="
    for func in "${FUNCTIONS[@]}"; do
        count=$(grep -c "$func" "$OUTPUT_FILE" 2>/dev/null || echo "0")
        echo "$func: $count 次调用"
    done
    echo ""
    echo "=== 函数执行时间统计 (前20) ==="
    grep -E "^\s+\|.*${FUNCTIONS[0]}" "$OUTPUT_FILE" | \
        grep -oE "[0-9]+\.[0-9]+ us" | \
        sort -n | head -20 || echo "无法提取时间信息"
} > "$OUTPUT_DIR/analysis.txt"

# 清理
echo nop > "$TRACE_DIR/current_tracer" 2>/dev/null || \
    sudo sh -c "echo nop > $TRACE_DIR/current_tracer"
echo > "$TRACE_DIR/set_ftrace_filter" 2>/dev/null || \
    sudo sh -c "echo > $TRACE_DIR/set_ftrace_filter"

echo ""
echo "=== 跟踪完成 ==="
echo "结果保存在: $OUTPUT_DIR"
echo ""
echo "查看跟踪结果:"
echo "  less $OUTPUT_FILE"
echo ""
echo "查看分析:"
echo "  cat $OUTPUT_DIR/analysis.txt"
echo ""
echo "提示: 跟踪文件可能很大，使用 less 或 head 查看"


