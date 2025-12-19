#!/bin/bash
# 分析 perf 结果目录，提取关键性能指标

set -e

if [ $# -lt 1 ]; then
    echo "用法: $0 <perf_results_directory>"
    echo "示例: $0 perf_results_rstat_official_20251219_095833"
    exit 1
fi

RESULT_DIR="$1"

if [ ! -d "$RESULT_DIR" ]; then
    echo "错误: 目录不存在: $RESULT_DIR"
    exit 1
fi

echo "=== 性能分析报告: $RESULT_DIR ==="
echo ""

# 1. 基础性能统计
if [ -f "$RESULT_DIR/perf_stat.txt" ]; then
    echo "--- 基础性能统计 ---"
    grep -E "seconds time elapsed|seconds user|seconds sys" "$RESULT_DIR/perf_stat.txt" | \
        sed 's/^[[:space:]]*/  /'
    
    echo ""
    echo "--- CPU 周期和指令 ---"
    grep -E "cycles|instructions" "$RESULT_DIR/perf_stat.txt" | \
        awk '{printf "  %-30s %15s\n", $1, $2}' | head -4
    
    echo ""
    echo "--- Cache 性能 ---"
    grep -E "cache-misses|cache-references" "$RESULT_DIR/perf_stat.txt" | \
        awk '{printf "  %-30s %15s", $1, $2; if(NF>3) printf " (%s)", $NF; printf "\n"}'
    
    echo ""
    echo "--- 分支预测 ---"
    grep "branch-misses" "$RESULT_DIR/perf_stat.txt" | \
        awk '{printf "  %-30s %15s\n", $1, $2}'
else
    echo "警告: perf_stat.txt 不存在"
fi

echo ""
echo "--- Top 10 热点函数 ---"
if [ -f "$RESULT_DIR/perf_report.txt" ]; then
    # 提取函数名和百分比
    grep -E "^[[:space:]]*[0-9]+\.[0-9]+%[[:space:]]+[0-9]+\.[0-9]+%" "$RESULT_DIR/perf_report.txt" | \
        head -10 | \
        awk '{printf "  %6.2f%%  %-50s\n", $1, $NF}'
else
    echo "警告: perf_report.txt 不存在"
fi

echo ""
echo "--- memory.stat 相关函数 ---"
if [ -f "$RESULT_DIR/perf_report.txt" ]; then
    grep -i "memory_stat" "$RESULT_DIR/perf_report.txt" | \
        grep -E "^[[:space:]]*[0-9]+\.[0-9]+%" | \
        head -5 | \
        awk '{printf "  %6.2f%%  %-50s\n", $1, $NF}'
fi

echo ""
echo "--- memory.numa_stat 相关函数 ---"
if [ -f "$RESULT_DIR/perf_report.txt" ]; then
    grep -i "memory_numa_stat" "$RESULT_DIR/perf_report.txt" | \
        grep -E "^[[:space:]]*[0-9]+\.[0-9]+%" | \
        head -5 | \
        awk '{printf "  %6.2f%%  %-50s\n", $1, $NF}'
fi

echo ""
echo "--- RSTAT 相关函数 ---"
if [ -f "$RESULT_DIR/perf_report.txt" ]; then
    RSTAT_FUNCS=$(grep -iE "rstat|memcg_rstat|css_rstat" "$RESULT_DIR/perf_report.txt" | \
        grep -E "^[[:space:]]*[0-9]+\.[0-9]+%" | head -10)
    if [ -z "$RSTAT_FUNCS" ]; then
        echo "  未找到 RSTAT 相关函数（可能开销很小，未出现在热点中）"
    else
        echo "$RSTAT_FUNCS" | awk '{printf "  %6.2f%%  %-50s\n", $1, $NF}'
    fi
fi

echo ""
echo "--- Atomic Counter 相关函数 ---"
if [ -f "$RESULT_DIR/perf_report.txt" ]; then
    ATOMIC_FUNCS=$(grep -iE "atomic|memcg_atomic" "$RESULT_DIR/perf_report.txt" | \
        grep -E "^[[:space:]]*[0-9]+\.[0-9]+%" | head -10)
    if [ -z "$ATOMIC_FUNCS" ]; then
        echo "  未找到 Atomic Counter 相关函数"
    else
        echo "$ATOMIC_FUNCS" | awk '{printf "  %6.2f%%  %-50s\n", $1, $NF}'
    fi
fi

echo ""
echo "--- 格式化相关函数 ---"
if [ -f "$RESULT_DIR/perf_report.txt" ]; then
    FORMAT_FUNCS=$(grep -iE "vsnprintf|format_decode|number|string|seq_printf|seq_buf_printf" "$RESULT_DIR/perf_report.txt" | \
        grep -E "^[[:space:]]*[0-9]+\.[0-9]+%" | head -10)
    if [ -n "$FORMAT_FUNCS" ]; then
        echo "$FORMAT_FUNCS" | awk '{printf "  %6.2f%%  %-50s\n", $1, $NF}'
        echo ""
        echo "  格式化函数总占比（估算）:"
        echo "$FORMAT_FUNCS" | awk '{sum+=$1} END {printf "  ~%.1f%%\n", sum}'
    fi
fi

echo ""
echo "=== 分析完成 ==="
echo ""
echo "详细报告请查看: $RESULT_DIR/ANALYSIS_REPORT.md"


