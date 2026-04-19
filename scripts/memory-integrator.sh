#!/bin/bash
# 记忆系统集成脚本
# 将自我改进与 memory-consolidate 集成

set +e

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
MEMORY_DIR="$HOME/.openclaw/agents/main"
MEMORY_SCRIPTS_DIR="$HOME/.openclaw/skills/hindsight-memory/scripts"
SKILL_DIR="${SKILL_DIR:-$HOME/.openclaw/skills/self-evolving-agent}"

echo "=== 记忆系统集成 - $(date) ==="

# 检查 memory-consolidate 是否存在
if [ ! -f "$MEMORY_SCRIPTS_DIR/memory-consolidate.js" ]; then
    echo "⚠️ memory-consolidate.js 未找到，跳过..."
    exit 0
fi

# 检查 MEMORY.md 是否超限
MEMORY_LINES=$(wc -l < "$MEMORY_DIR/MEMORY.md" 2>/dev/null || echo "0")
MEMORY_SIZE=$(du -k "$MEMORY_DIR/MEMORY.md" 2>/dev/null | cut -f1 || echo "0")

MAX_LINES=200
MAX_SIZE_KB=25

echo "MEMORY.md 状态: $MEMORY_LINES 行, ${MEMORY_SIZE}KB"

if [ "$MEMORY_LINES" -gt "$MAX_LINES" ] || [ "$MEMORY_SIZE" -gt "$((MAX_SIZE_KB * 1024))" ]; then
    echo "⚠️ MEMORY.md 超过限制，触发自动规整..."
    node "$MEMORY_SCRIPTS_DIR/memory-consolidate.js"
    echo "✅ 规整完成"
else
    echo "✅ MEMORY.md 状态正常"
fi

# 检查日志归档
if [ ! -f "$MEMORY_SCRIPTS_DIR/memory-archive.js" ]; then
    echo "⚠️ memory-archive.js 未找到，跳过归档检查..."
    exit 0
fi

# 检查日志数量
LOG_COUNT=$(find "$MEMORY_DIR/memory" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
echo "日志文件数量: $LOG_COUNT"

if [ "$LOG_COUNT" -gt 20 ]; then
    echo "⚠️ 日志文件过多 ($LOG_COUNT)，触发归档..."
    node "$MEMORY_SCRIPTS_DIR/memory-archive.js"
    echo "✅ 归档完成"
else
    echo "✅ 日志文件数量正常"
fi

echo "=== 记忆系统集成完成 ==="
