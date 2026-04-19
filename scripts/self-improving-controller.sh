#!/bin/bash
# Self-Evolving Agent - 自我改进控制器
# 协调所有自我改进组件
#
# 功能：
# 1. 性能监控（CPU/内存/磁盘）
# 2. 错误分析（命令失败、集成失败）
# 3. 优化引擎（自动触发优化）
# 4. 技能学习（分析需求缺口）
# 5. 反馈循环（持续改进）
# 6. 周度反思（Hindsight Reflect）
#
# 使用方式：
#   ./controller.sh              # 运行完整流程
#   ./controller.sh --monitor   # 仅运行性能监控
#   ./controller.sh --optimize  # 仅运行优化引擎
#
# 定时任务配置：
#   0 23 * * * /path/to/self-improving-controller.sh

set -e

# 配置
WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
SKILL_DIR="${SKILL_DIR:-$HOME/.openclaw/skills/self-evolving-agent}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    local missing=()
    
    for cmd in jq top free df curl; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_warning "缺少依赖: ${missing[*]}"
        log_info "安装命令: apt-get install ${missing[*]}"
    fi
}

# 初始化
init() {
    log_info "=== 自我改进控制器启动 $(date) ==="
    
    # 创建必要目录
    mkdir -p "$SELF_IMPROVING_DIR"/{monitoring,errors,optimizations,skills,feedback}
    mkdir -p "$SELF_IMPROVING_DIR/monitoring"
    
    # 初始化状态文件
    if [ ! -f "$SELF_IMPROVING_DIR/status.json" ]; then
        cat > "$SELF_IMPROVING_DIR/status.json" <<EOF
{
  "last_run": "$(date -Iseconds)",
  "components": {
    "monitoring": "pending",
    "error_analysis": "pending",
    "optimization": "pending",
    "skill_learning": "pending",
    "feedback": "pending",
    "reflection": "skipped"
  },
  "improvements_made": 0,
  "errors_detected": 0,
  "skills_learned": 0
}
EOF
    fi
}

# 运行性能监控
run_monitoring() {
    log_info "运行性能监控..."
    
    local script="$SKILL_DIR/scripts/performance-monitor.sh"
    if [ -f "$script" ]; then
        if bash "$script" >> "$SELF_IMPROVING_DIR/controller-$(date +%Y%m%d).log" 2>&1; then
            log_success "性能监控完成"
            jq '.components.monitoring = "completed"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
        else
            log_error "性能监控失败"
            jq '.components.monitoring = "failed"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
        fi
    else
        log_warning "性能监控脚本不存在: $script"
        jq '.components.monitoring = "skipped"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
    fi
}

# 运行错误分析
run_error_analysis() {
    log_info "运行错误分析..."
    
    local script="$SKILL_DIR/scripts/error-analyzer.sh"
    if [ -f "$script" ]; then
        if bash "$script" >> "$SELF_IMPROVING_DIR/controller-$(date +%Y%m%d).log" 2>&1; then
            log_success "错误分析完成"
            jq '.components.error_analysis = "completed"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
            
            # 统计错误数量
            local error_count=$(grep -c "错误" "$SELF_IMPROVING_DIR/errors/error-log-$(date +%Y%m%d).json" 2>/dev/null || echo "0")
            jq --arg count "$error_count" '.errors_detected = ($count | tonumber)' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
        else
            log_error "错误分析失败"
            jq '.components.error_analysis = "failed"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
        fi
    else
        log_warning "错误分析脚本不存在"
        jq '.components.error_analysis = "skipped"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
    fi
}

# 运行优化引擎
run_optimization() {
    log_info "检查优化触发条件..."
    
    if [ -f "$SELF_IMPROVING_DIR/optimizations/trigger.txt" ]; then
        log_info "发现优化触发条件，运行优化引擎..."
        
        local script="$SKILL_DIR/scripts/optimization-engine.sh"
        if [ -f "$script" ]; then
            if bash "$script" >> "$SELF_IMPROVING_DIR/controller-$(date +%Y%m%d).log" 2>&1; then
                log_success "优化引擎完成"
                jq '.components.optimization = "completed" | .improvements_made += 1' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
                rm "$SELF_IMPROVING_DIR/optimizations/trigger.txt"
            else
                log_error "优化引擎失败"
                jq '.components.optimization = "failed"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
            fi
        fi
    else
        log_info "没有优化触发条件，跳过优化引擎"
        jq '.components.optimization = "skipped"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
    fi
}

# 运行技能学习
run_skill_learning() {
    log_info "运行技能学习系统..."
    
    local script="$SKILL_DIR/scripts/skill-learner.sh"
    if [ -f "$script" ]; then
        if bash "$script" >> "$SELF_IMPROVING_DIR/controller-$(date +%Y%m%d).log" 2>&1; then
            log_success "技能学习完成"
            jq '.components.skill_learning = "completed"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
            
            # 统计学习的技能
            local skills_learned=$(grep -c "需要学习" "$SELF_IMPROVING_DIR/skills/learning-$(date +%Y%m%d).log" 2>/dev/null || echo "0")
            jq --arg count "$skills_learned" '.skills_learned = ($count | tonumber)' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
        else
            log_error "技能学习失败"
            jq '.components.skill_learning = "failed"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
        fi
    else
        log_warning "技能学习脚本不存在"
        jq '.components.skill_learning = "skipped"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
    fi
}

# 运行反馈循环
run_feedback() {
    log_info "运行反馈循环系统..."
    
    local script="$SKILL_DIR/scripts/feedback-loop.sh"
    if [ -f "$script" ]; then
        if bash "$script" >> "$SELF_IMPROVING_DIR/controller-$(date +%Y%m%d).log" 2>&1; then
            log_success "反馈循环完成"
            jq '.components.feedback = "completed"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
        else
            log_error "反馈循环失败"
            jq '.components.feedback = "failed"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
        fi
    else
        log_warning "反馈循环脚本不存在"
        jq '.components.feedback = "skipped"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
    fi
}

# 运行记忆规整（整合 hindsight-memory）
run_memory_integrator() {
    log_info "运行记忆规整系统..."
    
    local script="$SKILL_DIR/scripts/memory-integrator.sh"
    if [ -f "$script" ]; then
        if bash "$script" >> "$SELF_IMPROVING_DIR/controller-$(date +%Y%m%d).log" 2>&1; then
            log_success "记忆规整完成"
        else
            log_error "记忆规整失败"
        fi
    else
        log_warning "记忆规整脚本不存在"
    fi
}

# 运行周度反思
run_reflection() {
    local day_of_week=$(date +%u)
    
    if [ $day_of_week -eq 7 ]; then
        log_info "今天是周日，运行周度反思..."
        
        local script="$SKILL_DIR/scripts/memory-reflect.sh"
        if [ -f "$script" ]; then
            if bash "$script" 7 >> "$SELF_IMPROVING_DIR/controller-$(date +%Y%m%d).log" 2>&1; then
                log_success "周度反思完成"
                jq '.components.reflection = "completed"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
            else
                log_error "周度反思失败"
                jq '.components.reflection = "failed"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
            fi
        else
            log_warning "反思脚本不存在: $script"
        fi
    else
        log_info "今日非周日（周$day_of_week），跳过周度反思"
        jq '.components.reflection = "skipped"' "$SELF_IMPROVING_DIR/status.json" > "$SELF_IMPROVING_DIR/status.json.tmp" && mv "$SELF_IMPROVING_DIR/status.json.tmp" "$SELF_IMPROVING_DIR/status.json"
    fi
}

# 生成改进报告
generate_report() {
    log_info "生成改进报告..."
    
    local final_status=$(cat "$SELF_IMPROVING_DIR/status.json")
    local report_file="$SELF_IMPROVING_DIR/report-$(date +%Y%m%d-%H%M).md"
    
    cat > "$report_file" <<EOF
# 自我改进报告
**生成时间：** $(date)

## 执行状态
$(echo "$final_status" | jq -r '.components | to_entries | map("- \(.key): \(.value)") | join("\n")')

## 改进成果
- 检测到的错误: $(echo "$final_status" | jq -r '.errors_detected')
- 完成的改进: $(echo "$final_status" | jq -r '.improvements_made')
- 学习的技能: $(echo "$final_status" | jq -r '.skills_learned')

## 详细日志
\`\`\`
$(tail -50 "$SELF_IMPROVING_DIR/controller-$(date +%Y%m%d).log" 2>/dev/null || echo "无日志")
\`\`\`

## 建议
1. 定期运行自我改进控制器
2. 监控系统性能变化
3. 根据反馈调整优化策略

---

*此报告由 Self-Evolving Agent 自动生成*
EOF

    log_success "改进报告已生成: $report_file"
    
    # 更新长期记忆
    update_memory
}

# 更新长期记忆
update_memory() {
    log_info "更新长期记忆..."
    
    local final_status=$(cat "$SELF_IMPROVING_DIR/status.json")
    
    if [ -f "$WORKSPACE/MEMORY.md" ]; then
        cat >> "$WORKSPACE/MEMORY.md" <<EOF

## 自我改进执行报告 $(date +%Y-%m-%d)
**执行时间：** $(date)
**状态：** 已完成
**检测错误：** $(echo "$final_status" | jq -r '.errors_detected')
**完成改进：** $(echo "$final_status" | jq -r '.improvements_made')
**学习技能：** $(echo "$final_status" | jq -r '.skills_learned')
---
EOF
    fi
}

# 发送通知
send_notification() {
    local final_status=$(cat "$SELF_IMPROVING_DIR/status.json")
    local errors=$(echo "$final_status" | jq -r '.errors_detected')
    local improvements=$(echo "$final_status" | jq -r '.improvements_made')
    
    if [ "$errors" -gt 5 ] || [ "$improvements" -gt 0 ]; then
        log_info "重要事件需要通知"
        # 这里可以添加微信通知逻辑
    fi
}

# 显示帮助
show_help() {
    cat <<EOF
Self-Evolving Agent - 自我改进控制器

用法:
    ./self-improving-controller.sh [选项]

选项:
    --monitor      仅运行性能监控
    --optimize     仅运行优化引擎
    --errors       仅运行错误分析
    --skills       仅运行技能学习
    --memory     仅运行记忆规整
    --feedback     仅运行反馈循环
    --reflect      仅运行周度反思
    --report       仅生成报告
    --help         显示此帮助信息

示例:
    ./self-improving-controller.sh           # 运行完整流程
    ./self-improving-controller.sh --monitor # 仅监控

定时任务:
    0 23 * * * /path/to/self-improving-controller.sh

EOF
}

# 主函数
main() {
    check_dependencies
    init
    
    case "${1:-}" in
        --monitor)
            run_monitoring
            ;;
        --optimize)
            run_optimization
            ;;
        --errors)
            run_error_analysis
            ;;
        --skills)
            run_skill_learning
            ;;
        --memory)
            run_memory_integrator
            ;;
        --feedback)
            run_feedback
            ;;
        --reflect)
            run_reflection
            ;;
        --report)
            generate_report
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            # 运行完整流程
            run_monitoring
            run_error_analysis
            run_optimization
            run_skill_learning
            run_memory_integrator
            run_feedback
            run_reflection
            generate_report
            send_notification
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
    
    log_success "=== 自我改进控制器完成 $(date) ==="
}

main "$@"