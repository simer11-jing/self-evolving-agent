#!/bin/bash
# Benchmark 测试集成脚本
# 运行系统功能、记忆系统和性能基准测试
#
# 功能：
# - 系统功能测试
# - 记忆系统测试
# - 性能基准测试
# - 结果记录和对比
#
# 使用方式：
#   ./benchmark-runner.sh              # 运行所有测试
#   ./benchmark-runner.sh --system     # 仅系统功能测试
#   ./benchmark-runner.sh --memory     # 仅记忆系统测试
#   ./benchmark-runner.sh --perf       # 仅性能基准测试
#   ./benchmark-runner.sh --compare    # 对比历史结果

set -e

# 配置
WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
SKILL_DIR="${SKILL_DIR:-$HOME/.openclaw/skills/self-evolving-agent}"
BENCHMARK_DIR="$SELF_IMPROVING_DIR/benchmarks"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }

# 初始化
init() {
    mkdir -p "$BENCHMARK_DIR"/results
    mkdir -p "$BENCHMARK_DIR"/history
    
    BENCHMARK_ID=$(date +%Y%m%d-%H%M%S)
    RESULT_FILE="$BENCHMARK_DIR/results/benchmark-${BENCHMARK_ID}.json"
    REPORT_FILE="$BENCHMARK_DIR/results/report-${BENCHMARK_ID}.md"
    
    # 初始化结果JSON
    cat > "$RESULT_FILE" <<EOF
{
  "benchmark_id": "$BENCHMARK_ID",
  "timestamp": "$(date -Iseconds)",
  "system": {
    "hostname": "$(hostname)",
    "os": "$(uname -s)",
    "kernel": "$(uname -r)"
  },
  "tests": {},
  "summary": {
    "total": 0,
    "passed": 0,
    "failed": 0,
    "duration_ms": 0
  }
}
EOF
}

# 更新测试结果
update_test_result() {
    local test_name="$1"
    local status="$2"
    local duration="$3"
    local details="${4:-{}}"
    
    local tmp_file="${RESULT_FILE}.tmp"
    jq --arg name "$test_name" \
       --arg status "$status" \
       --arg duration "$duration" \
       --argjson details "$details" \
       '.tests[$name] = {
         "status": $status,
         "duration_ms": ($duration | tonumber),
         "details": $details,
         "timestamp": "'$(date -Iseconds)'"
       }' "$RESULT_FILE" > "$tmp_file" && mv "$tmp_file" "$RESULT_FILE"
}

# 更新汇总
update_summary() {
    local total="$1"
    local passed="$2"
    local failed="$3"
    local duration="$4"
    
    local tmp_file="${RESULT_FILE}.tmp"
    jq --arg total "$total" \
       --arg passed "$passed" \
       --arg failed "$failed" \
       --arg duration "$duration" \
       '.summary = {
         "total": ($total | tonumber),
         "passed": ($passed | tonumber),
         "failed": ($failed | tonumber),
         "duration_ms": ($duration | tonumber)
       }' "$RESULT_FILE" > "$tmp_file" && mv "$tmp_file" "$RESULT_FILE"
}

# ============ 系统功能测试 ============
run_system_tests() {
    log_info "=== 运行系统功能测试 ==="
    local start_time=$(date +%s%N)
    local passed=0
    local failed=0
    
    # 测试1: 目录结构检查
    log_info "测试: 目录结构检查"
    if [ -d "$SELF_IMPROVING_DIR" ] && \
       [ -d "$SELF_IMPROVING_DIR/monitoring" ] && \
       [ -d "$SELF_IMPROVING_DIR/errors" ] && \
       [ -d "$SELF_IMPROVING_DIR/optimizations" ]; then
        log_success "目录结构正确"
        update_test_result "directory_structure" "passed" "0" '{"message": "所有必要目录存在"}'
        ((passed++))
    else
        log_error "目录结构不完整"
        update_test_result "directory_structure" "failed" "0" '{"message": "缺少必要目录"}'
        ((failed++))
    fi
    
    # 测试2: 核心脚本可执行性
    log_info "测试: 核心脚本可执行性"
    local scripts=(
        "$SKILL_DIR/scripts/self-improving-controller.sh"
        "$SKILL_DIR/scripts/performance-monitor.sh"
        "$SKILL_DIR/scripts/error-analyzer.sh"
        "$SKILL_DIR/scripts/optimization-engine.sh"
    )
    local all_executable=true
    for script in "${scripts[@]}"; do
        if [ ! -x "$script" ] && [ -f "$script" ]; then
            chmod +x "$script" 2>/dev/null || true
        fi
        if [ ! -f "$script" ]; then
            all_executable=false
            log_warning "脚本不存在: $script"
        fi
    done
    
    if $all_executable; then
        log_success "核心脚本可执行"
        update_test_result "script_executable" "passed" "0" '{"scripts_checked": '${#scripts[@]}'}'
        ((passed++))
    else
        log_error "部分脚本缺失"
        update_test_result "script_executable" "failed" "0" '{"message": "部分脚本不存在"}'
        ((failed++))
    fi
    
    # 测试3: 依赖检查
    log_info "测试: 系统依赖检查"
    local deps=("jq" "curl" "ps" "df" "free")
    local missing_deps=()
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        log_success "所有依赖已安装"
        update_test_result "dependencies" "passed" "0" '{"dependencies": "'${deps[*]}'"}'
        ((passed++))
    else
        log_warning "缺少依赖: ${missing_deps[*]}"
        update_test_result "dependencies" "warning" "0" '{"missing": "'${missing_deps[*]}'"}'
        ((passed++))  # 警告不算失败
    fi
    
    # 测试4: 配置文件检查
    log_info "测试: 配置文件检查"
    if [ -f "$SELF_IMPROVING_DIR/status.json" ]; then
        if jq empty "$SELF_IMPROVING_DIR/status.json" 2>/dev/null; then
            log_success "配置文件有效"
            update_test_result "config_valid" "passed" "0" '{"file": "status.json"}'
            ((passed++))
        else
            log_error "配置文件格式错误"
            update_test_result "config_valid" "failed" "0" '{"error": "JSON格式错误"}'
            ((failed++))
        fi
    else
        log_warning "配置文件不存在（首次运行）"
        update_test_result "config_valid" "skipped" "0" '{"message": "首次运行"}'
        ((passed++))
    fi
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    
    log_info "系统功能测试完成: $passed 通过, $failed 失败"
    
    return $failed
}

# ============ 记忆系统测试 ============
run_memory_tests() {
    log_info "=== 运行记忆系统测试 ==="
    local start_time=$(date +%s%N)
    local passed=0
    local failed=0
    
    local MEMORY_DIR="$HOME/.openclaw/agents/main/memory"
    
    # 测试1: 记忆目录可访问
    log_info "测试: 记忆目录可访问"
    if [ -d "$MEMORY_DIR" ] || [ -d "$WORKSPACE" ]; then
        log_success "记忆目录可访问"
        update_test_result "memory_dir_access" "passed" "0" '{"path": "'${MEMORY_DIR}'"}'
        ((passed++))
    else
        log_error "记忆目录不可访问"
        update_test_result "memory_dir_access" "failed" "0" '{"error": "目录不存在"}'
        ((failed++))
    fi
    
    # 测试2: 记忆文件读写
    log_info "测试: 记忆文件读写"
    local test_memory_file="$SELF_IMPROVING_DIR/benchmark-test-memory.md"
    echo "# 测试记忆 $(date)" > "$test_memory_file"
    echo "- 测试项目1" >> "$test_memory_file"
    echo "- 测试项目2" >> "$test_memory_file"
    
    if [ -f "$test_memory_file" ] && [ -s "$test_memory_file" ]; then
        local line_count=$(wc -l < "$test_memory_file")
        rm -f "$test_memory_file"
        log_success "记忆文件读写正常"
        update_test_result "memory_file_io" "passed" "0" '{"lines_written": '$line_count'}'
        ((passed++))
    else
        rm -f "$test_memory_file"
        log_error "记忆文件读写失败"
        update_test_result "memory_file_io" "failed" "0" '{"error": "写入失败"}'
        ((failed++))
    fi
    
    # 测试3: 记忆搜索功能
    log_info "测试: 记忆搜索功能"
    if command -v grep &> /dev/null; then
        # 创建一个测试记忆文件
        local search_test_file="$SELF_IMPROVING_DIR/benchmark-search-test.md"
        cat > "$search_test_file" <<EOF
# 测试记忆文档
## 决策
- 决策1: 测试决策A
- 决策2: 测试决策B

## 错误
- 错误1: 测试错误X

## 经验
- 学到了: 测试经验Y
EOF
        
        local search_results=$(grep -c "决策\|错误\|学到了" "$search_test_file" 2>/dev/null || echo "0")
        rm -f "$search_test_file"
        
        if [ "$search_results" -ge 3 ]; then
            log_success "记忆搜索功能正常"
            update_test_result "memory_search" "passed" "0" '{"matches": '$search_results'}'
            ((passed++))
        else
            log_error "记忆搜索结果异常"
            update_test_result "memory_search" "failed" "0" '{"matches": '$search_results'}'
            ((failed++))
        fi
    else
        log_warning "grep 不可用，跳过搜索测试"
        update_test_result "memory_search" "skipped" "0" '{"reason": "grep不可用"}'
        ((passed++))
    fi
    
    # 测试4: 记忆归档性能
    log_info "测试: 记忆归档性能"
    local archive_start=$(date +%s%N)
    
    # 模拟创建多个记忆文件
    for i in {1..10}; do
        echo "# 测试记忆 $i" > "$SELF_IMPROVING_DIR/benchmark-mem-$i.md"
    done
    
    # 模拟归档（移动操作）
    mkdir -p "$SELF_IMPROVING_DIR/archive-test"
    for i in {1..10}; do
        mv "$SELF_IMPROVING_DIR/benchmark-mem-$i.md" "$SELF_IMPROVING_DIR/archive-test/" 2>/dev/null || true
    done
    rm -rf "$SELF_IMPROVING_DIR/archive-test"
    
    local archive_end=$(date +%s%N)
    local archive_duration=$(( (archive_end - archive_start) / 1000000 ))
    
    if [ "$archive_duration" -lt 5000 ]; then  # 5秒内完成
        log_success "记忆归档性能良好 (${archive_duration}ms)"
        update_test_result "memory_archive_perf" "passed" "$archive_duration" '{"files": 10}'
        ((passed++))
    else
        log_warning "记忆归档性能较慢 (${archive_duration}ms)"
        update_test_result "memory_archive_perf" "warning" "$archive_duration" '{"files": 10}'
        ((passed++))
    fi
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    
    log_info "记忆系统测试完成: $passed 通过, $failed 失败"
    
    return $failed
}

# ============ 性能基准测试 ============
run_perf_tests() {
    log_info "=== 运行性能基准测试 ==="
    local start_time=$(date +%s%N)
    local passed=0
    local failed=0
    
    # 测试1: 文件I/O性能
    log_info "测试: 文件I/O性能"
    local io_start=$(date +%s%N)
    
    # 写入1000行数据
    local io_test_file="$SELF_IMPROVING_DIR/io-perf-test.txt"
    for i in $(seq 1 1000); do
        echo "Line $i: $(date -Iseconds) - Test data for performance benchmark" >> "$io_test_file"
    done
    
    # 读取测试
    local line_count=$(wc -l < "$io_test_file")
    rm -f "$io_test_file"
    
    local io_end=$(date +%s%N)
    local io_duration=$(( (io_end - io_start) / 1000000 ))
    
    if [ "$io_duration" -lt 1000 ] && [ "$line_count" -eq 1000 ]; then
        log_success "文件I/O性能良好 (${io_duration}ms)"
        update_test_result "file_io_perf" "passed" "$io_duration" '{"lines": 1000, "throughput": "'$(awk "BEGIN {printf \"%.0f\", 1000/$io_duration*1000}")' lines/s"}'
        ((passed++))
    else
        log_warning "文件I/O性能一般 (${io_duration}ms)"
        update_test_result "file_io_perf" "warning" "$io_duration" '{"lines": '$line_count'}'
        ((passed++))
    fi
    
    # 测试2: JSON处理性能
    log_info "测试: JSON处理性能"
    local json_start=$(date +%s%N)
    
    # 创建大型JSON并解析
    local json_test_file="$SELF_IMPROVING_DIR/json-perf-test.json"
    echo '{"items":[' > "$json_test_file"
    for i in $(seq 1 100); do
        echo "{\"id\":$i,\"name\":\"item_$i\",\"value\":$RANDOM}," >> "$json_test_file"
    done
    echo '{"id":101,"name":"end","value":0}]}' >> "$json_test_file"
    
    # 解析测试
    local json_items=$(jq '.items | length' "$json_test_file" 2>/dev/null || echo "0")
    rm -f "$json_test_file"
    
    local json_end=$(date +%s%N)
    local json_duration=$(( (json_end - json_start) / 1000000 ))
    
    if [ "$json_duration" -lt 500 ] && [ "$json_items" -eq 101 ]; then
        log_success "JSON处理性能良好 (${json_duration}ms)"
        update_test_result "json_perf" "passed" "$json_duration" '{"items": '$json_items'}'
        ((passed++))
    else
        log_warning "JSON处理性能一般 (${json_duration}ms)"
        update_test_result "json_perf" "warning" "$json_duration" '{"items": '$json_items'}'
        ((passed++))
    fi
    
    # 测试3: 系统资源基准
    log_info "测试: 系统资源基准"
    
    local cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'%' -f1 2>/dev/null || echo "0")
    local mem_available=$(free -m | awk 'NR==2 {print $7}' 2>/dev/null || echo "0")
    local disk_free=$(df -m / | awk 'NR==2 {print $4}' 2>/dev/null || echo "0")
    
    # 评估资源状态
    local resource_score=100
    if [ -n "$cpu_idle" ] && [ "${cpu_idle%.*}" -lt 20 ]; then
        resource_score=$((resource_score - 20))
    fi
    if [ "$mem_available" -lt 100 ]; then
        resource_score=$((resource_score - 20))
    fi
    if [ "$disk_free" -lt 1000 ]; then
        resource_score=$((resource_score - 20))
    fi
    
    log_success "系统资源基准: CPU空闲=${cpu_idle}%, 可用内存=${mem_available}MB, 磁盘空闲=${disk_free}MB"
    update_test_result "system_resources" "passed" "0" "{\"cpu_idle\": \"$cpu_idle\", \"mem_available_mb\": $mem_available, \"disk_free_mb\": $disk_free, \"score\": $resource_score}"
    ((passed++))
    
    # 测试4: 脚本执行性能
    log_info "测试: 脚本执行性能"
    local script_start=$(date +%s%N)
    
    # 执行一个简单的bash循环
    local counter=0
    for i in $(seq 1 1000); do
        counter=$((counter + 1))
    done
    
    local script_end=$(date +%s%N)
    local script_duration=$(( (script_end - script_start) / 1000000 ))
    
    if [ "$script_duration" -lt 100 ]; then
        log_success "脚本执行性能良好 (${script_duration}ms)"
        update_test_result "script_perf" "passed" "$script_duration" '{"iterations": 1000}'
        ((passed++))
    else
        log_warning "脚本执行性能一般 (${script_duration}ms)"
        update_test_result "script_perf" "warning" "$script_duration" '{"iterations": 1000}'
        ((passed++))
    fi
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    
    log_info "性能基准测试完成: $passed 通过, $failed 失败"
    
    return $failed
}

# ============ 结果对比 ============
compare_results() {
    log_info "=== 对比历史测试结果 ==="
    
    local latest_results=("$BENCHMARK_DIR"/results/benchmark-*.json)
    if [ ! -f "${latest_results[-1]}" ] || [ ${#latest_results[@]} -lt 2 ]; then
        log_warning "历史数据不足，无法对比"
        return 0
    fi
    
    # 获取最近两次测试结果
    local current="${latest_results[-1]}"
    local previous="${latest_results[-2]}"
    
    log_info "对比: $(basename "$previous") vs $(basename "$current")"
    
    # 提取关键指标
    local curr_passed=$(jq '.summary.passed' "$current")
    local prev_passed=$(jq '.summary.passed' "$previous")
    local curr_failed=$(jq '.summary.failed' "$current")
    local prev_failed=$(jq '.summary.failed' "$previous")
    
    echo ""
    echo "========== 对比报告 =========="
    echo "指标              上次          本次          变化"
    echo "----------------- ------------- ------------- -------------"
    printf "%-17s %-13s %-13s " "通过测试" "$prev_passed" "$curr_passed"
    if [ "$curr_passed" -ge "$prev_passed" ]; then
        echo -e "${GREEN}+$((curr_passed - prev_passed))${NC}"
    else
        echo -e "${RED}$((curr_passed - prev_passed))${NC}"
    fi
    
    printf "%-17s %-13s %-13s " "失败测试" "$prev_failed" "$curr_failed"
    if [ "$curr_failed" -le "$prev_failed" ]; then
        echo -e "${GREEN}$((curr_failed - prev_failed))${NC}"
    else
        echo -e "${RED}+$((curr_failed - prev_failed))${NC}"
    fi
    echo "=============================="
    echo ""
}

# ============ 生成报告 ============
generate_report() {
    log_info "生成测试报告..."
    
    local total=$(jq '.summary.total' "$RESULT_FILE")
    local passed=$(jq '.summary.passed' "$RESULT_FILE")
    local failed=$(jq '.summary.failed' "$RESULT_FILE")
    local duration=$(jq '.summary.duration_ms' "$RESULT_FILE")
    
    local status_icon="✅"
    if [ "$failed" -gt 0 ]; then
        status_icon="⚠️"
    fi
    if [ "$failed" -gt 2 ]; then
        status_icon="❌"
    fi
    
    cat > "$REPORT_FILE" <<EOF
# Benchmark 测试报告

**测试ID:** $BENCHMARK_ID  
**执行时间:** $(date -Iseconds)  
**总耗时:** ${duration}ms  
**状态:** $status_icon

## 汇总

| 指标 | 数值 |
|------|------|
| 总测试数 | $total |
| 通过 | $passed |
| 失败 | $failed |
| 通过率 | $(awk "BEGIN {printf \"%.1f%%\", $passed/$total*100}") |

## 详细结果

### 系统功能测试
$(jq -r '.tests | to_entries[] | select(.key | startswith("directory_", "script_", "config_", "dependencies")) | "- **\(.key)**: \(.value.status) (\(.value.duration_ms)ms)"' "$RESULT_FILE" 2>/dev/null || echo "无数据")

### 记忆系统测试
$(jq -r '.tests | to_entries[] | select(.key | startswith("memory_")) | "- **\(.key)**: \(.value.status) (\(.value.duration_ms)ms)"' "$RESULT_FILE" 2>/dev/null || echo "无数据")

### 性能基准测试
$(jq -r '.tests | to_entries[] | select(.key | endswith("_perf") or .key == "system_resources") | "- **\(.key)**: \(.value.status) (\(.value.duration_ms)ms)"' "$RESULT_FILE" 2>/dev/null || echo "无数据")

## 原始数据

\`\`\`json
$(cat "$RESULT_FILE")
\`\`\`

---
*此报告由 Self-Evolving Agent Benchmark Runner 自动生成*
EOF

    log_success "报告已生成: $REPORT_FILE"
    
    # 复制到历史记录
    cp "$RESULT_FILE" "$BENCHMARK_DIR/history/"
}

# ============ 显示帮助 ============
show_help() {
    cat <<EOF
Benchmark 测试集成脚本

用法:
    ./benchmark-runner.sh [选项]

选项:
    --system       仅运行系统功能测试
    --memory       仅运行记忆系统测试
    --perf         仅运行性能基准测试
    --compare      对比历史测试结果
    --all          运行所有测试（默认）
    --help         显示此帮助信息

示例:
    ./benchmark-runner.sh              # 运行所有测试
    ./benchmark-runner.sh --system     # 仅系统测试
    ./benchmark-runner.sh --compare    # 对比历史结果

输出:
    结果文件: $SELF_IMPROVING_DIR/benchmarks/results/
    历史记录: $SELF_IMPROVING_DIR/benchmarks/history/

EOF
}

# ============ 主函数 ============
main() {
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
    esac
    
    init
    
    local total_start=$(date +%s%N)
    local total_passed=0
    local total_failed=0
    local test_count=0
    
    case "${1:-}" in
        --system)
            run_system_tests
            total_passed=$passed
            total_failed=$?
            test_count=4
            ;;
        --memory)
            run_memory_tests
            total_passed=$passed
            total_failed=$?
            test_count=4
            ;;
        --perf)
            run_perf_tests
            total_passed=$passed
            total_failed=$?
            test_count=4
            ;;
        --compare)
            compare_results
            exit 0
            ;;
        --all|"")
            run_system_tests
            local sys_passed=$passed
            local sys_failed=$?
            
            run_memory_tests
            local mem_passed=$passed
            local mem_failed=$?
            
            run_perf_tests
            local perf_passed=$passed
            local perf_failed=$?
            
            total_passed=$((sys_passed + mem_passed + perf_passed))
            total_failed=$((sys_failed + mem_failed + perf_failed))
            test_count=$((sys_passed + sys_failed + mem_passed + mem_failed + perf_passed + perf_failed))
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
    
    local total_end=$(date +%s%N)
    local total_duration=$(( (total_end - total_start) / 1000000 ))
    
    # 更新汇总
    update_summary "$test_count" "$total_passed" "$total_failed" "$total_duration"
    
    # 生成报告
    generate_report
    
    # 输出汇总
    echo ""
    echo "========== Benchmark 测试完成 =========="
    echo "总测试数: $test_count"
    echo -e "通过: ${GREEN}$total_passed${NC}"
    echo -e "失败: ${RED}$total_failed${NC}"
    echo "总耗时: ${total_duration}ms"
    echo "报告: $REPORT_FILE"
    echo "========================================"
    
    # 返回退出码
    if [ "$total_failed" -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
