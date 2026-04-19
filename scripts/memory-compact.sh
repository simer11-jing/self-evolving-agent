#!/bin/bash
# 记忆层压缩脚本
# 调用 hindsight-memory 的 build-vector-index.js 进行压缩和清理

set -e

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
MEMORY_SKILL="$HOME/.openclaw/skills/hindsight-memory"

echo "=== 记忆压缩 - $(date) ==="

# 压缩稀疏层（保留高置信度条目）
echo "📦 压缩稀疏记忆层..."
node "$MEMORY_SKILL/scripts/build-vector-index.js" --compact 2>&1 | tail -5

# 清理过期向量索引（保留最近7天）
echo "🧹 清理过期索引..."
node "$MEMORY_SKILL/scripts/build-vector-index.js" --clean 2>&1 | tail -5

echo "=== 记忆压缩完成 - $(date) ==="
