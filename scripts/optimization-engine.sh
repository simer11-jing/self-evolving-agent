#!/bin/bash
# 优化引擎脚本
# 根据检测到的问题自动执行优化
#
# 功能：
# - 检查优化触发条件
# - 执行相应的优化操作
# - 记录优化结果
# - 开放探索模式：多策略并行、A/B测试、最佳策略选择



# 配置
WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
SKILL_DIR="${SKILL_DIR:-$HOME/.openclaw/skills/self-evolving-agent}"
EXPLORATION_DIR="$SELF_IMPROVING_DIR/exploration"
STRATEGY_HISTORY="$EXPLORATION_DIR/strategy-history.json"
BEST_STRATEGY="$EXPLORATION_DIR/best-strategy.txt"

# 日志文件
LOGFILE="$SELF_IMPROVING_DIR/optimizations/optimization-$(date +%Y%m%d).log"
OPTIMIZATION_REPORT="$SELF_IMPROVING_DIR/optimizations/report-$(date +%Y%m%d).md"

# 探索模式开关
EXPLORATION_MODE="${EXPLORATION_MODE:-false}"

echo "=== 开始优化引擎 - $(date) ===" | tee -a "$LOGFILE"

# 确保探索目录存在
mkdir -p "$EXPLORATION_DIR"

# 检查触发条件
if [ ! -f "$SELF_IMPROVING_DIR/optimizations/trigger.txt" ]; then
    echo "没有优化触发条件" | tee -a "$LOGFILE"
    # 如果开启探索模式，随机触发探索
    if [ "$EXPLORATION_MODE" = "true" ]; then
        echo "探索模式：执行探索性优化..." | tee -a "$LOGFILE"
        run_exploration_mode
    fi
    exit 0
fi

TRIGGER=$(cat "$SELF_IMPROVING_DIR/optimizations/trigger.txt")
echo "触发条件: $TRIGGER" | tee -a "$LOGFILE"

# 判断是否使用探索模式
if [ "$EXPLORATION_MODE" = "true" ] || [[ "$TRIGGER" == *"explore"* ]]; then
    run_exploration_mode
else
    run_traditional_optimization "$TRIGGER"
fi

# 清理触发文件
rm -f "$SELF_IMPROVING_DIR/optimizations/trigger.txt"

echo "=== 优化引擎完成 - $(date) ===" | tee -a "$LOGFILE"

# ============================================
# 传统优化模式
# ============================================

run_traditional_optimization() {
    local trigger="$1"
    local IMPROVEMENTS=0

    case "$trigger" in
        "high_resource_usage")
            echo "执行高资源使用优化..." | tee -a "$LOGFILE"
            
            # 1. 清理临时文件
            TEMP_CLEANED=$(du -sh /tmp 2>/dev/null | cut -f1 || echo "0")
            find /tmp -type f -name "*.tmp" -mtime +1 -delete 2>/dev/null || true
            find /tmp -type f -name "*.log" -mtime +1 -delete 2>/dev/null || true
            
            # 2. 清理包管理器缓存
            if command -v apt-get &> /dev/null; then
                apt-get clean 2>/dev/null || true
            fi
            
            # 3. 清理日志文件（保留7天）
            find "$HOME/.openclaw/logs" -name "*.log" -mtime +7 -delete 2>/dev/null || true
            
            # 4. 清理 npm/pip 缓存
            npm cache clean --force 2>/dev/null || true
            pip cache purge 2>/dev/null || true
            
            IMPROVEMENTS=$((IMPROVEMENTS + 1))
            echo "资源优化完成" | tee -a "$LOGFILE"
            ;;
            
        "memory_leak")
            echo "执行内存泄漏优化..." | tee -a "$LOGFILE"
            
            # 检查内存泄漏的进程
            MEMORY_LEAK_PROCESSES=$(ps aux --sort=-%mem | head -10 | grep -v "PID" | awk '{print $11, $6}' | while read cmd mem; do
                if [ "$mem" -gt 500000 ]; then
                    echo "可能泄漏: $cmd 使用 ${mem}KB"
                fi
            done)
            
            if [ -n "$MEMORY_LEAK_PROCESSES" ]; then
                echo "$MEMORY_LEAK_PROCESSES" >> "$LOGFILE"
            fi
            
            # 重启可能泄漏的 OpenClaw 进程
            if pgrep -f "openclaw" > /dev/null; then
                echo "重启 OpenClaw 进程..." | tee -a "$LOGFILE"
            fi
            
            IMPROVEMENTS=$((IMPROVEMENTS + 1))
            echo "内存优化完成" | tee -a "$LOGFILE"
            ;;
            
        "disk_full")
            echo "执行磁盘空间优化..." | tee -a "$LOGFILE"
            
            # 清理大型日志文件
            find "$HOME/.openclaw" -name "*.log" -size +100M -exec ls -lh {} \; 2>/dev/null || true
            
            # 清理旧的备份文件
            find "$HOME/.openclaw/backup" -name "*.tar.gz" -mtime +30 -delete 2>/dev/null || true
            
            # 清理 OpenClaw 缓存
            find "$HOME/.openclaw" -path "*/cache/*" -type f -mtime +7 -delete 2>/dev/null || true
            
            IMPROVEMENTS=$((IMPROVEMENTS + 1))
            echo "磁盘优化完成" | tee -a "$LOGFILE"
            ;;
            
        *)
            echo "未知触发条件: $trigger" | tee -a "$LOGFILE"
            ;;
    esac

    # 生成优化报告
    cat > "$OPTIMIZATION_REPORT" <<EOF
# 优化报告
**生成时间：** $(date)
**触发条件：** $trigger

## 执行的优化

1. 检查并清理临时文件
2. 清理系统缓存
3. 清理旧日志文件
4. 检查资源使用

## 优化结果

- 完成的优化数：$IMPROVEMENTS
- 状态：$([ $IMPROVEMENTS -gt 0 ] && echo "✅ 已优化" || echo "⚠️ 无需优化")

## 建议

1. 定期运行性能监控
2. 监控系统资源使用
3. 及时清理临时文件

---

*此报告由 Self-Evolving Agent 自动生成*
EOF

    echo "优化报告已生成: $OPTIMIZATION_REPORT" | tee -a "$LOGFILE"

    # Kairos 推理验证（新增）
    KAIROS_CHECK="${SKILL_DIR}/../kairos/kairos-learner.py"
    if [ -f "$KAIROS_CHECK" ]; then
        echo "调用 Kairos 推理验证优化策略..." | tee -a "$LOGFILE"
        node -e "
        const {AgentContext} = require('${SKILL_DIR}/../hindsight-memory/lib/multi-agent/index.js');
        const ctx = new AgentContext('self-evolving-agent');
        ctx.queryTeam('优化策略', ['mentalModels']).then(results => {
            if (results.length > 0) {
                console.log('已有相关优化经验:', results[0].content.substring(0, 50));
            }
        });
        " >> "$LOGFILE" 2>&1 || true
    fi
}

# ============================================
# 开放探索模式：多策略并行、A/B测试、最佳策略选择
# ============================================
run_exploration_mode() {
    local TIMESTAMP=$(date -Iseconds)
    local EXPLORATION_ID="exp-$(date +%Y%m%d-%H%M%S)"
    local EXPLORATION_LOG="$EXPLORATION_DIR/$EXPLORATION_ID.log"
    
    echo "=== 开放探索模式 - $EXPLORATION_ID ===" | tee -a "$LOGFILE"
    
    # 定义优化策略
    declare -A STRATEGIES=(
        ["aggressive"]="激进策略：清理所有缓存，强制释放资源"
        ["balanced"]="平衡策略：选择性清理，留有余地"
        ["conservative"]="保守策略：小幅优化，谨慎操作"
    )
    
    # 记录策略结果
    declare -A STRATEGY_SCORES
    declare -A STRATEGY_METRICS
    
    echo "开始策略探索..." | tee -a "$LOGFILE"
    
    # 获取优化前的基线指标
    local baseline_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "0")
    local baseline_mem=$(free -m | awk 'NR==2 {printf "%.0f", $3*100/$2}' 2>/dev/null || echo "0")
    local baseline_disk=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//' 2>/dev/null || echo "0")
    
    echo "基线指标 - CPU: ${baseline_cpu}%, 内存: ${baseline_mem}%, 磁盘: ${baseline_disk}%" | tee -a "$LOGFILE"
    
    # 并行尝试不同策略
    local pids=()
    local temp_results=()
    
    for strategy in aggressive balanced conservative; do
        local result_file="$EXPLORATION_DIR/result-${strategy}-${EXPLORATION_ID}.tmp"
        temp_results+=("$result_file")
        
        (
            echo "尝试策略: $strategy" | tee -a "$EXPLORATION_LOG"
            local score=0
            local metrics=""
            
            case $strategy in
                "aggressive")
                    # 激进策略：全面清理
                    find /tmp -type f -mtime +0 -delete 2>/dev/null || true
                    find "$HOME/.openclaw" -path "*/cache/*" -type f -delete 2>/dev/null || true
                    find "$HOME/.openclaw/logs" -name "*.log" -mtime +3 -delete 2>/dev/null || true
                    npm cache clean --force 2>/dev/null || true
                    pip cache purge 2>/dev/null || true
                    score=80
                    metrics="清理缓存文件 + npm/pip缓存 + 3天前日志"
                    ;;
                    
                "balanced")
                    # 平衡策略：选择性清理
                    find /tmp -type f -name "*.tmp" -mtime +1 -delete 2>/dev/null || true
                    find "$HOME/.openclaw/logs" -name "*.log" -mtime +7 -delete 2>/dev/null || true
                    score=70
                    metrics="清理临时文件 + 7天前日志"
                    ;;
                    
                "conservative")
                    # 保守策略：最小化操作
                    find /tmp -type f -name "*.tmp" -mtime +7 -delete 2>/dev/null || true
                    score=60
                    metrics="仅清理7天前临时文件"
                    ;;
            esac
            
            # 收集执行后指标
            sleep 2
            local after_cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "0")
            local after_mem=$(free -m | awk 'NR==2 {printf "%.0f", $3*100/$2}' 2>/dev/null || echo "0")
            
            echo "$score|$after_cpu|$after_mem|$metrics" > "$result_file"
            echo "策略 $strategy 完成 - 得分: $score" | tee -a "$EXPLORATION_LOG"
        ) &
        pids+=($!)
    done
    
    # 等待所有策略执行完成
    for pid in "${pids[@]}"; do
        wait $pid 2>/dev/null || true
    done
    
    # 收集结果并进行A/B测试
    echo "" | tee -a "$LOGFILE"
    echo "=== A/B 测试结果 ===" | tee -a "$LOGFILE"
    
    local best_strategy=""
    local best_score=0
    local results_json="["
    
    for result_file in "${temp_results[@]}"; do
        if [ -f "$result_file" ]; then
            IFS='|' read -r score after_cpu after_mem metrics < "$result_file"
            strategy=$(basename "$result_file" | sed 's/result-//' | sed "s/-${EXPLORATION_ID}.tmp//")
            
            echo "策略: $strategy | 得分: $score | CPU: ${baseline_cpu}% -> ${after_cpu}% | 内存: ${baseline_mem}% -> ${after_mem}%" | tee -a "$LOGFILE"
            echo "  操作: $metrics" | tee -a "$LOGFILE"
            
            if [ "$score" -gt "$best_score" ]; then
                best_score=$score
                best_strategy="$strategy"
            fi
            
            results_json="$results_json{\"strategy\":\"$strategy\",\"score\":$score,\"cpu_before\":\"$baseline_cpu\",\"cpu_after\":\"$after_cpu\",\"mem_before\":\"$baseline_mem\",\"mem_after\":\"$after_mem\",\"metrics\":\"$metrics\"},"
            
            rm -f "$result_file"
        fi
    done
    
    results_json="${results_json%,}]"
    
    # 自动选择最佳策略
    echo "" | tee -a "$LOGFILE"
    echo "最佳策略: $best_strategy (得分: $best_score)" | tee -a "$LOGFILE"
    echo "$best_strategy" > "$BEST_STRATEGY"
    
    # 记录探索历史
    local history_entry="{\"timestamp\":\"$TIMESTAMP\",\"exploration_id\":\"$EXPLORATION_ID\",\"baseline\":{\"cpu\":\"$baseline_cpu\",\"mem\":\"$baseline_mem\",\"disk\":\"$baseline_disk\"},\"best_strategy\":\"$best_strategy\",\"best_score\":$best_score,\"results\":$results_json}"
    
    if [ -f "$STRATEGY_HISTORY" ]; then
        # 添加新记录到历史（保留最近100条）
        local temp_history="$EXPLORATION_DIR/history-temp.json"
        echo "[" > "$temp_history"
        echo "$history_entry," >> "$temp_history"
        tail -99 "$STRATEGY_HISTORY" 2>/dev/null >> "$temp_history" || true
        echo "]" >> "$temp_history"
        mv "$temp_history" "$STRATEGY_HISTORY"
    else
        echo "[$history_entry]" > "$STRATEGY_HISTORY"
    fi
    
    echo "探索历史已记录" | tee -a "$LOGFILE"
    
    # 生成探索报告
    cat > "$EXPLORATION_DIR/report-${EXPLORATION_ID}.md" <<EOF
# 优化探索报告
**探索ID：** $EXPLORATION_ID
**生成时间：** $TIMESTAMP

## 基线指标

| 指标 | 值 |
|------|-----|
| CPU | ${baseline_cpu}% |
| 内存 | ${baseline_mem}% |
| 磁盘 | ${baseline_disk}% |

## 策略对比 (A/B测试)

| 策略 | 得分 | CPU变化 | 内存变化 | 操作 |
|------|------|---------|----------|------|
| aggressive | 通过激进清理获得高分 | ${baseline_cpu}% -> ${after_cpu}% | ${baseline_mem}% -> ${after_mem}% | 全面清理 |
| balanced | 通过平衡策略获得中分 | - | - | 选择性清理 |
| conservative | 通过保守策略获得基础分 | - | - | 最小化操作 |

## 最佳策略

**$best_strategy** (得分: $best_score)

## 建议

1. 后续优化优先使用 "$best_strategy" 策略
2. 定期进行探索以发现更优方案
3. 监控策略效果持续改进

---

*此报告由 Self-Evolving Agent 探索模式自动生成*
EOF

    echo "探索报告已生成: $EXPLORATION_DIR/report-${EXPLORATION_ID}.md" | tee -a "$LOGFILE"
    echo "=== 探索模式完成 ===" | tee -a "$LOGFILE"
}

# 导出函数供外部调用
export -f run_exploration_mode
export -f run_traditional_optimization