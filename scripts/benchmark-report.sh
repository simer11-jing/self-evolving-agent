#!/bin/bash
# Self-Evolving Agent - Benchmark 运行与报告生成工具
# 定期运行 Benchmark，生成趋势图表和对比报告

set -e

# 配置
WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
BENCHMARK_DIR="$WORKSPACE/self-improving/benchmarks"
REPORT_FILE="${REPORT_FILE:-/tmp/self-evolving-agent/docs/BENCHMARKS.md}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 初始化目录
mkdir -p "$BENCHMARK_DIR"
mkdir -p "$(dirname "$REPORT_FILE")"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# 模拟运行 Benchmark (实际应用中替换为真实的评测命令)
run_benchmark() {
    log_info "正在运行 Benchmark 测试..."
    local timestamp=$(date +%s)
    local date_str=$(date +%Y-%m-%d\ %H:%M:%S)
    
    # 模拟生成一些指标数据 (0-100)
    local success_rate=$(( (RANDOM % 20) + 80 )) # 80-100
    local response_time=$(( (RANDOM % 500) + 100 )) # 100-600ms
    local resolution_rate=$(( (RANDOM % 30) + 70 )) # 70-100
    
    local result_file="$BENCHMARK_DIR/${timestamp}.json"
    
    cat > "$result_file" <<EOF
{
  "timestamp": $timestamp,
  "date": "$date_str",
  "metrics": {
    "success_rate": $success_rate,
    "response_time_ms": $response_time,
    "issue_resolution_rate": $resolution_rate
  }
}
EOF
    
    log_success "Benchmark 运行完成，结果保存在: $result_file"
    echo "$result_file"
}

# 生成基于历史数据的报告
generate_report() {
    log_info "正在生成 Benchmark 报告..."
    
    # 初始化/清空报告文件
    cat > "$REPORT_FILE" <<EOF
# Self-Evolving Agent - 性能与能力基准测试 (Benchmarks)

本文档自动记录代理的性能基准测试结果，并展示其进化趋势。

## 最近更新: $(date +%Y-%m-%d\ %H:%M:%S)

## 趋势图表 (最近10次测试)

EOF
    
    # 获取最近10次结果
    local recent_files=$(ls -1t "$BENCHMARK_DIR"/*.json 2>/dev/null | head -n 10 | sort)
    
    if [ -z "$recent_files" ]; then
        echo "> 暂无测试数据" >> "$REPORT_FILE"
        log_info "无数据，报告生成结束"
        return 0
    fi
    
    # 提取数据并生成简单的文本图表
    echo '```text' >> "$REPORT_FILE"
    echo "成功率趋势 (Success Rate %):" >> "$REPORT_FILE"
    
    for file in $recent_files; do
        local date=$(jq -r '.date' "$file" | cut -d' ' -f1 | tail -c 6)
        local rate=$(jq -r '.metrics.success_rate' "$file")
        local bar=$(printf '%0.s#' $(seq 1 $((rate / 2))))
        printf "%-6s | %-50s %s%%\n" "$date" "$bar" "$rate" >> "$REPORT_FILE"
    done
    
    echo "" >> "$REPORT_FILE"
    echo "问题解决率趋势 (Resolution Rate %):" >> "$REPORT_FILE"
    for file in $recent_files; do
        local date=$(jq -r '.date' "$file" | cut -d' ' -f1 | tail -c 6)
        local rate=$(jq -r '.metrics.issue_resolution_rate' "$file")
        local bar=$(printf '%0.s#' $(seq 1 $((rate / 2))))
        printf "%-6s | %-50s %s%%\n" "$date" "$bar" "$rate" >> "$REPORT_FILE"
    done
    echo '```' >> "$REPORT_FILE"
    
    # 历史对比表格
    cat >> "$REPORT_FILE" <<EOF

## 详细历史对比

| 测试日期 | 成功率 (%) | 平均响应时间 (ms) | 问题解决率 (%) |
| :--- | :--- | :--- | :--- |
EOF
    
    # 降序排列的详细表格
    local all_files=$(ls -1t "$BENCHMARK_DIR"/*.json 2>/dev/null)
    for file in $all_files; do
        local date=$(jq -r '.date' "$file")
        local sr=$(jq -r '.metrics.success_rate' "$file")
        local rt=$(jq -r '.metrics.response_time_ms' "$file")
        local rr=$(jq -r '.metrics.issue_resolution_rate' "$file")
        
        echo "| $date | $sr | $rt | $rr |" >> "$REPORT_FILE"
    done
    
    log_success "报告已生成并更新至: $REPORT_FILE"
}

# 确保安装了 jq
if ! command -v jq &> /dev/null; then
    log_info "正在安装依赖 jq..."
    sudo apt-get update && sudo apt-get install -y jq >/dev/null 2>&1 || {
        log_error "无法安装 jq，请手动安装后重试。"
        exit 1
    }
fi

# 主逻辑
case "$1" in
    run)
        run_benchmark
        generate_report
        ;;
    report)
        generate_report
        ;;
    *)
        echo "使用方法: $0 [run|report]"
        echo "  run    - 运行基准测试并生成报告"
        echo "  report - 仅根据现有数据重新生成报告"
        exit 1
        ;;
esac

exit 0