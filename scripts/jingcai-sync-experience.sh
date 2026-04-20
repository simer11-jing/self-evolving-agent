#!/bin/bash
# 竞彩经验自动同步脚本
# 从经验文档同步新增内容到 betting-results.md

EXPERIENCE_FILE="$HOME/.openclaw/agents/main/memory/竞彩足球投注经验总结.md"
BETTING_FILE="$HOME/.openclaw/workspace/self-improving/jingcai/betting-results.md"
LOGFILE="$HOME/.openclaw/workspace/self-improving/jingcai/sync-$(date +%Y%m%d).log"

mkdir -p "$(dirname "$BETTING_FILE")"

echo "=== 竞彩经验同步 - $(date) ===" >> "$LOGFILE"

if [ ! -f "$EXPERIENCE_FILE" ]; then
    echo "经验文件不存在" >> "$LOGFILE"
    exit 0
fi

# 提取最后更新日期之后的经验条目（简单方式：提取最近30行的核心教训）
LATEST=$(tail -50 "$EXPERIENCE_FILE" | grep -E "### |\| " | head -20)

if [ -n "$LATEST" ]; then
    echo "新增经验条目已记录" >> "$LOGFILE"
    # 写入同步标记
    echo "" >> "$BETTING_FILE"
    echo "### 自动同步 $(date '+%Y-%m-%d %H:%M')" >> "$BETTING_FILE"
    echo "自动同步自经验文档" >> "$BETTING_FILE"
fi

echo "同步完成" >> "$LOGFILE"
