#!/bin/bash
# 错误分析脚本 v2.0
# 分析并记录错误模式，支持 SQLite 存储

set +e

# 配置
WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
SKILL_DIR="${SKILL_DIR:-$HOME/.openclaw/skills/self-evolving-agent}"
ERRORS_DB="$SELF_IMPROVING_DIR/errors/errors.db"

mkdir -p "$SELF_IMPROVING_DIR/errors"

LOGFILE="$SELF_IMPROVING_DIR/errors/error-log-$(date +%Y%m%d).json"
ERROR_SUMMARY="$SELF_IMPROVING_DIR/errors/error-summary-$(date +%Y%m%d).md"

echo "=== 开始错误分析 - $(date) ===" | tee -a "$LOGFILE"

ERRORS_FOUND=0
NEW_ERRORS=0

# 初始化 SQLite 数据库
init_db() {
    sqlite3 "$ERRORS_DB" << 'SQL_EOF' 2>/dev/null
CREATE TABLE IF NOT EXISTS errors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    source TEXT NOT NULL,
    error_type TEXT,
    message TEXT,
    count INTEGER DEFAULT 1,
    resolved INTEGER DEFAULT 0,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS error_patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    error_type TEXT UNIQUE,
    description TEXT,
    solution TEXT,
    occurrence_count INTEGER DEFAULT 1,
    last_seen TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_errors_timestamp ON errors(timestamp);
CREATE INDEX IF NOT EXISTS idx_errors_source ON errors(source);
CREATE INDEX IF NOT EXISTS idx_error_patterns_type ON error_patterns(error_type);
SQL_EOF
}

# 插入错误记录
insert_error() {
    local source="$1"
    local error_type="$2"
    local message="$3"
    
    sqlite3 "$ERRORS_DB" << SQL_EOF 2>/dev/null
INSERT INTO errors (timestamp, source, error_type, message)
VALUES ('$(date -Iseconds)', '$source', '$error_type', '$message');

INSERT INTO error_patterns (error_type, description, occurrence_count, last_seen)
VALUES ('$error_type', '$message', 1, '$(date -Iseconds)')
ON CONFLICT(error_type) DO UPDATE SET
    occurrence_count = occurrence_count + 1,
    last_seen = '$(date -Iseconds)';
SQL_EOF
}

# 初始化数据库
init_db

# 分析 OpenClaw 错误日志
if [ -d "$HOME/.openclaw/logs" ]; then
    RECENT_ERRORS=$(find "$HOME/.openclaw/logs" -name "*.log" -mtime -1 -exec grep -l "ERROR" {} \; 2>/dev/null | head -5)
    
    if [ -n "$RECENT_ERRORS" ]; then
        echo "发现错误日志文件: $RECENT_ERRORS" | tee -a "$LOGFILE"
        
        for logfile in $RECENT_ERRORS; do
            ERROR_COUNT=$(grep -c "ERROR" "$logfile" 2>/dev/null || echo "0")
            ERRORS_FOUND=$((ERRORS_FOUND + ERROR_COUNT))
            
            # 提取错误类型并存储
            while IFS= read -r line; do
                error_type=$(echo "$line" | grep -oP 'ERROR[^\s]+|\[ERROR[^\]]*\]' | head -1)
                message=$(echo "$line" | grep -oP 'Error:[^,]+' | head -1)
                if [ -n "$error_type" ]; then
                    insert_error "openclaw" "$error_type" "$message"
                    NEW_ERRORS=$((NEW_ERRORS + 1))
                fi
            done < <(grep "ERROR" "$logfile" 2>/dev/null | head -20)
        done
    fi
fi

# 分析 Cron 任务错误
if [ -d "$HOME/.openclaw/cron/runs" ]; then
    FAILED_JOBS=$(find "$HOME/.openclaw/cron/runs" -name "*.jsonl" -mtime -1 -exec grep -l "error" {} \; 2>/dev/null | head -5)
    
    if [ -n "$FAILED_JOBS" ]; then
        echo "发现失败的 Cron 任务" | tee -a "$LOGFILE"
        
        for job in $FAILED_JOBS; do
            ERROR_COUNT=$(grep -c "error" "$job" 2>/dev/null || echo "0")
            ERRORS_FOUND=$((ERRORS_FOUND + ERROR_COUNT))
            
            while IFS= read -r line; do
                error_type="cron_error"
                message=$(echo "$line" | cut -c1-200)
                insert_error "cron" "$error_type" "$message"
                NEW_ERRORS=$((NEW_ERRORS + 1))
            done < <(grep "error" "$job" 2>/dev/null | head -10)
        done
    fi
fi

# 查询常见错误模式
COMMON_PATTERNS=$(sqlite3 -header -column "$ERRORS_DB" << 'SQL_EOF' 2>/dev/null
SELECT error_type, COUNT(*) as count, MAX(timestamp) as last_seen
FROM errors 
WHERE timestamp > datetime('now', '-7 days')
GROUP BY error_type 
ORDER BY count DESC 
LIMIT 10;
SQL_EOF
)

# 生成报告
cat > "$ERROR_SUMMARY" << REPORT_EOF
# 错误分析报告
**生成时间：** $(date)

## 错误统计

| 指标 | 数值 |
|------|------|
| 本次分析发现错误 | $ERRORS_FOUND |
| 新增错误记录 | $NEW_ERRORS |
| 数据库总错误数 | $(sqlite3 "$ERRORS_DB" "SELECT COUNT(*) FROM errors;" 2>/dev/null || echo "N/A") |

## 常见错误模式（近7天）

$(sqlite3 -header -column "$ERRORS_DB" "SELECT error_type, COUNT(*) as count FROM errors WHERE timestamp > datetime('now', '-7 days') GROUP BY error_type ORDER BY count DESC LIMIT 10;" 2>/dev/null | head -20)

## 修复建议

1. **高频错误**：查看上表中的高频错误类型，针对性修复
2. **Cron 失败**：检查定时任务配置和网络连接
3. **资源问题**：考虑清理磁盘或增加内存
4. **API 错误**：检查 API 密钥和配额

## 相关文件

- 错误数据库: $ERRORS_DB
- 日志文件: $LOGFILE

---

*此报告由 Self-Evolving Agent v2.0 自动生成*
REPORT_EOF

echo "错误报告已生成: $ERROR_SUMMARY" | tee -a "$LOGFILE"
echo "发现错误数: $ERRORS_FOUND" | tee -a "$LOGFILE"
echo "新增记录: $NEW_ERRORS" | tee -a "$LOGFILE"
echo "=== 错误分析完成 - $(date) ===" | tee -a "$LOGFILE"

# 触发记忆规整（如果有新错误）
if [ "$NEW_ERRORS" -gt 5 ]; then
    echo "发现较多新错误 ($NEW_ERRORS)，触发记忆反思..." | tee -a "$LOGFILE"
    # 调用 memory-reflect 脚本（如果存在）
    if [ -x "$SKILL_DIR/scripts/memory-reflect.sh" ]; then
        "$SKILL_DIR/scripts/memory-reflect.sh" "error" 2>/dev/null || true
    fi
fi

# 清理旧错误日志
find "$SELF_IMPROVING_DIR/errors" -name "error-*.json" -mtime +30 -delete 2>/dev/null || true
find "$SELF_IMPROVING_DIR/errors" -name "error-summary-*.md" -mtime +30 -delete 2>/dev/null || true
