#!/bin/bash
# 竞彩临场监控 wrapper（由 daemon 调用）
# 时间窗口内才执行：21:00-21:30

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NODE_BIN="${NODE_BIN:-node}"

$NODE_BIN "$SCRIPT_DIR/jingcai-realtime-monitor.js" "$@"
