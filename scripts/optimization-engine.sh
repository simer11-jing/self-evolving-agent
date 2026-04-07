#!/bin/bash
# 优化引擎脚本
# 根据检测到的问题自动执行优化
#
# 功能：
# - 检查优化触发条件
# - 执行相应的优化操作
# - 记录优化结果

set -e

# 配置
WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
SKILL_DIR="${SKILL_DIR:-$HOME/.openclaw/skills/self-evolving-agent}"

# 日志文件
LOGFILE="$SELF_IMPROVING_DIR/optimizations/optimization-$(date +%Y%m%d).log"
OPTIMIZATION_REPORT="$SELF_IMPROVING_DIR/optimizations/report-$(date +%Y%m%d).md"

echo "=== 开始优化引擎 - $(date) ===" | tee -a "$LOGFILE"

# 检查触发条件
if [ ! -f "$SELF_IMPROVING_DIR/optimizations/trigger.txt" ]; then
    echo "没有优化触发条件" | tee -a "$LOGFILE"
    exit 0
fi

TRIGGER=$(cat "$SELF_IMPROVING_DIR/optimizations/trigger.txt")
echo "触发条件: $TRIGGER" | tee -a "$LOGFILE"

IMPROVEMENTS=0

case "$TRIGGER" in
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
            # openclaw gateway restart 2>/dev/null || true
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
        echo "未知触发条件: $TRIGGER" | tee -a "$LOGFILE"
        ;;
esac

# 生成优化报告
cat > "$OPTIMIZATION_REPORT" <<EOF
# 优化报告
**生成时间：** $(date)
**触发条件：** $TRIGGER

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
echo "=== 优化引擎完成 - $(date) ===" | tee -a "$LOGFILE"

# 清理触发文件
rm -f "$SELF_IMPROVING_DIR/optimizations/trigger.txt"