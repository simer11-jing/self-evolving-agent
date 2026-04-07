#!/bin/bash
# 技能学习系统
# 自动学习和添加新技能
#
# 功能：
# - 分析用户需求模式
# - 检查现有技能
# - 确定需要学习的技能
# - 通过 alphaclaw 自动学习新技能

set -e

# 配置
WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
SKILLS_DIR="${SKILLS_DIR:-$HOME/.openclaw/skills}"
CLAWHUB_CACHE="$WORKSPACE/.clawhub/cache"

# 日志文件
LOGFILE="$SELF_IMPROVING_DIR/skills/learning-$(date +%Y%m%d).log"

echo "=== 开始技能学习系统 - $(date) ===" | tee -a "$LOGFILE"

# 1. 分析用户需求模式
echo "分析用户需求模式..." | tee -a "$LOGFILE"

REQUIREMENT_PATTERNS=""

# 检查最近的会话记录
if [ -d "$HOME/.openclaw/agents/main/sessions" ]; then
    RECENT_SESSIONS=$(find "$HOME/.openclaw/agents/main/sessions" -name "*.jsonl" -mtime -1 2>/dev/null | head -5)
    
    for session in $RECENT_SESSIONS; do
        if [ -f "$session" ]; then
            # 提取用户请求中的关键词
            USER_REQUESTS=$(grep -o '"content":"[^"]*"' "$session" 2>/dev/null | grep -v "assistant" | head -10)
            
            # 分析需求模式
            if echo "$USER_REQUESTS" | grep -qi "weather\|温度\|天气"; then
                REQUIREMENT_PATTERNS="$REQUIREMENT_PATTERNS|weather"
            fi
            if echo "$USER_REQUESTS" | grep -qi "code\|编程\|代码"; then
                REQUIREMENT_PATTERNS="$REQUIREMENT_PATTERNS|coding"
            fi
            if echo "$USER_REQUESTS" | grep -qi "search\|搜索\|查找"; then
                REQUIREMENT_PATTERNS="$REQUIREMENT_PATTERNS|search"
            fi
            if echo "$USER_REQUESTS" | grep -qi "file\|文件\|文档"; then
                REQUIREMENT_PATTERNS="$REQUIREMENT_PATTERNS|file_management"
            fi
            if echo "$USER_REQUESTS" | grep -qi "system\|系统\|配置"; then
                REQUIREMENT_PATTERNS="$REQUIREMENT_PATTERNS|system_admin"
            fi
            if echo "$USER_REQUESTS" | grep -qi "email\|邮件\|邮箱"; then
                REQUIREMENT_PATTERNS="$REQUIREMENT_PATTERNS|email"
            fi
            if echo "$USER_REQUESTS" | grep -qi "stock\|股票\|投资"; then
                REQUIREMENT_PATTERNS="$REQUIREMENT_PATTERNS|finance"
            fi
        fi
    done
fi

REQUIREMENT_PATTERNS=$(echo "$REQUIREMENT_PATTERNS" | sed 's/^|//' | sed 's/|$//')
echo "检测到的需求模式: ${REQUIREMENT_PATTERNS:-无}" | tee -a "$LOGFILE"

# 2. 检查现有技能
EXISTING_SKILLS=""
if [ -d "$SKILLS_DIR" ]; then
    EXISTING_SKILLS=$(ls "$SKILLS_DIR" 2>/dev/null | grep -v "^\\.?" | tr '\n' ' ')
fi
echo "现有技能: ${EXISTING_SKILLS:-无}" | tee -a "$LOGFILE"

# 3. 确定需要学习的技能
NEEDED_SKILLS=""

# 检查技能缺口
if [[ "$REQUIREMENT_PATTERNS" == *"weather"* ]] && ! echo "$EXISTING_SKILLS" | grep -qi "weather"; then
    NEEDED_SKILLS="$NEEDED_SKILLS weather"
    echo "需要学习天气技能" | tee -a "$LOGFILE"
fi

if [[ "$REQUIREMENT_PATTERNS" == *"email"* ]] && ! echo "$EXISTING_SKILLS" | grep -qi "email\|gog"; then
    NEEDED_SKILLS="$NEEDED_SKILLS email"
    echo "需要学习邮件技能" | tee -a "$LOGFILE"
fi

if [[ "$REQUIREMENT_PATTERNS" == *"finance"* ]] && ! echo "$EXISTING_SKILLS" | grep -qi "stock\|finance"; then
    NEEDED_SKILLS="$NEEDED_SKILLS finance"
    echo "需要学习金融技能" | tee -a "$LOGFILE"
fi

if [[ "$REQUIREMENT_PATTERNS" == *"search"* ]] && ! echo "$EXISTING_SKILLS" | grep -qi "search\|web"; then
    NEEDED_SKILLS="$NEEDED_SKILLS web_search"
    echo "需要学习网页搜索技能" | tee -a "$LOGFILE"
fi

if [[ "$REQUIREMENT_PATTERNS" == *"file_management"* ]] && ! echo "$EXISTING_SKILLS" | grep -qi "file\|document"; then
    NEEDED_SKILLS="$NEEDED_SKILLS file_management"
    echo "需要学习文件管理技能" | tee -a "$LOGFILE"
fi

# 4. 学习新技能
if [ -n "$NEEDED_SKILLS" ]; then
    echo "开始学习新技能: $NEEDED_SKILLS" | tee -a "$LOGFILE"
    
    # 检查是否有 alphaclaw
    if command -v alphaclaw &> /dev/null; then
        echo "使用 alphaclaw 技能商店..." | tee -a "$LOGFILE"
        
        for skill in $NEEDED_SKILLS; do
            case $skill in
                "weather")
                    echo "学习天气技能..." | tee -a "$LOGFILE"
                    alphaclaw search "weather" 2>/dev/null | head -5 | tee -a "$LOGFILE"
                    ;;
                "email")
                    echo "学习邮件技能..." | tee -a "$LOGFILE"
                    alphaclaw search "email" 2>/dev/null | head -5 | tee -a "$LOGFILE"
                    ;;
                "finance")
                    echo "学习金融技能..." | tee -a "$LOGFILE"
                    alphaclaw search "stock finance" 2>/dev/null | head -5 | tee -a "$LOGFILE"
                    ;;
                "web_search")
                    echo "学习网页搜索技能..." | tee -a "$LOGFILE"
                    alphaclaw search "web search" 2>/dev/null | head -5 | tee -a "$LOGFILE"
                    ;;
                "file_management")
                    echo "学习文件管理技能..." | tee -a "$LOGFILE"
                    alphaclaw search "file document" 2>/dev/null | head -5 | tee -a "$LOGFILE"
                    ;;
            esac
        done
    else
        echo "警告：alphaclaw 未安装，无法自动获取技能" | tee -a "$LOGFILE"
        echo "建议手动安装：npm install -g alphaclaw" | tee -a "$LOGFILE"
    fi
    
    # 记录学习结果
    echo "技能学习完成: $NEEDED_SKILLS" | tee -a "$LOGFILE"
else
    echo "没有检测到需要学习的新技能" | tee -a "$LOGFILE"
fi

# 5. 优化现有技能
echo "优化现有技能..." | tee -a "$LOGFILE"

if [ -d "$SKILLS_DIR" ]; then
    for skill_dir in "$SKILLS_DIR"/*/; do
        if [ -d "$skill_dir" ] && [ -f "${skill_dir}SKILL.md" ]; then
            skill_name=$(basename "$skill_dir")
            skill_md="${skill_dir}SKILL.md"
            
            # 检查技能最后修改时间
            last_modified=$(stat -c %Y "$skill_md" 2>/dev/null || echo "0")
            days_old=$(( ($(date +%s) - last_modified) / 86400 ))
            
            if [ $days_old -gt 30 ]; then
                echo "技能 '$skill_name' 已超过 $days_old 天未更新，建议检查更新" | tee -a "$LOGFILE"
            fi
        fi
    done
fi

echo "=== 技能学习系统完成 - $(date) ===" | tee -a "$LOGFILE"

# 6. 清理旧日志（保留30天）
find "$SELF_IMPROVING_DIR/skills" -name "learning-*.log" -mtime +30 -delete 2>/dev/null || true