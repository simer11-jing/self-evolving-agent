#!/bin/bash
# daemon健康检查 + 自动重启
# 由 cron 调用（建议每5分钟一次）

SCRIPT_DIR="$HOME/.openclaw/skills/self-evolving-agent"
DAEMON="$SCRIPT_DIR/self-evolving-daemon.js"
STATE_FILE="$HOME/.openclaw/workspace/self-improving/daemon-state.json"
PID=""
MAX_AGE_SEC=600  # 10分钟无心跳视为崩溃

# 1. 检查 daemon 是否在运行
check_running() {
    # 尝试从 state file 或 process list 找 PID
    PID=$(grep -o '"pid":[0-9]*' "$STATE_FILE" 2>/dev/null | grep -o '[0-9]*' | head -1)
    
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        return 0  # 进程存活
    fi
    
    # 备选：直接找 node 进程
    PID=$(pgrep -f "self-evolving-daemon.js" | head -1)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        return 0
    fi
    
    return 1  # 进程未运行
}

# 2. 检查心跳是否过期（基于最新任务运行时间）
check_heartbeat() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "⚠️ 无 state 文件"
        return 1
    fi

    LAST_RUN=$(python3 -c "
import json, sys
try:
    d = json.load(open('$STATE_FILE'))
    runs = [v.get('lastRun', 0) for v in d.get('tasks', {}).values()]
    print(max(runs)) if runs else print(0)
except: print(0)
" 2>/dev/null)

    if [ -z "$LAST_RUN" ] || [ "$LAST_RUN" = "0" ]; then
        echo "⚠️ 无任务运行记录"
        return 1
    fi

    NOW_MS=$(python3 -c "import time; print(int(time.time() * 1000))")
    AGE_SEC=$(( (NOW_MS - LAST_RUN) / 1000 ))

    if [ $AGE_SEC -gt $MAX_AGE_SEC ]; then
        echo "⚠️ 任务过期 ($AGE_SEC 秒无运行)"
        return 1
    fi

    echo "✅ daemon 健康 (最近任务 ${AGE_SEC}s 前)"
    return 0
}

# 3. 重启 daemon
do_restart() {
    echo "🔄 重启 self-evolving-daemon..."
    
    # 杀掉旧进程（如果还存在）
    if [ -n "$PID" ]; then
        kill "$PID" 2>/dev/null || true
    fi
    pkill -f "self-evolving-daemon.js" 2>/dev/null || true
    sleep 1
    
    # 启动新进程（后台运行）
    cd "$SCRIPT_DIR"
    nohup node self-evolving-daemon.js >> "$SCRIPT_DIR/logs/daemon.log" 2>&1 &
    NEW_PID=$!
    echo "✅ daemon 已启动 (PID=$NEW_PID)"
    
    # 通知（直接调用 CLI，不通过 require）
    node "$HOME/.openclaw/agents/main/send_feishu.js" "🔄 Self-Evolving Daemon 自动重启 (PID=$NEW_PID)" 2>/dev/null || true
}

# 主流程
if check_running && check_heartbeat; then
    echo "$(date): ✅ daemon 正常运行"
else
    echo "$(date): ❌ daemon 异常，准备重启"
    do_restart
fi
