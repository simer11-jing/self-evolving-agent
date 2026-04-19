#!/bin/bash
# 记忆反思脚本
# 基于 Hindsight 架构进行周期性反思
#
# 功能：
# - 回顾过去一周/一个月的记忆
# - 识别模式和改进点
# - 更新长期记忆
#
# 使用方式：
#   ./memory-reflect.sh 7    # 周度反思
#   ./memory-reflect.sh 30   # 月度反思

set -e

# 配置
WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
SELF_IMPROVING_DIR="$WORKSPACE/self-improving"
SKILL_DIR="${SKILL_DIR:-$HOME/.openclaw/skills/self-evolving-agent}"
MEMORY_DIR="$HOME/.openclaw/agents/main/memory"

# 日志文件
LOGFILE="$SELF_IMPROVING_DIR/monitoring/reflect-$(date +%Y%m%d).log"
REFLECT_REPORT="$SELF_IMPROVING_DIR/monitoring/reflection-$(date +%Y%m%d).md"

# 获取周期参数（默认7天）
PERIOD="${1:-7}"

echo "=== 开始记忆反思 - $(date) ===" | tee -a "$LOGFILE"
echo "反思周期: $PERIOD 天" | tee -a "$LOGFILE"

# 1. 收集记忆文件
echo "收集过去 $PERIOD 天的记忆文件..." | tee -a "$LOGFILE"

MEMORY_FILES=$(find "$MEMORY_DIR" -name "????-??-??.md" -mtime -$PERIOD 2>/dev/null | sort)

if [ -z "$MEMORY_FILES" ]; then
    echo "没有找到过去的记忆文件" | tee -a "$LOGFILE"
    exit 0
fi

MEMORY_COUNT=$(echo "$MEMORY_FILES" | wc -l)
echo "找到 $MEMORY_COUNT 个记忆文件" | tee -a "$LOGFILE"

# 2. 分析记忆内容
echo "分析记忆内容..." | tee -a "$LOGFILE"

# 统计决策数量
DECISIONS=$(grep -c "## 决策" $MEMORY_FILES 2>/dev/null || echo "0")
echo "决策数量: $DECISIONS" | tee -a "$LOGFILE"

# 统计错误数量
ERRORS=$(grep -c "错误\|失败\|Error" $MEMORY_FILES 2>/dev/null || echo "0")
echo "错误数量: $ERRORS" | tee -a "$LOGFILE"

# 统计改进数量
IMPROVEMENTS=$(grep -c "改进\|优化\|优化" $MEMORY_FILES 2>/dev/null || echo "0")
echo "改进数量: $IMPROVEMENTS" | tee -a "$LOGFILE"

# 3. 生成反思报告
cat > "$REFLECT_REPORT" <<EOF
# 记忆反思报告
**生成时间：** $(date)
**反思周期：** 过去 $PERIOD 天

## 统计摘要

- 记忆文件数：$MEMORY_COUNT
- 决策数量：$DECISIONS
- 错误数量：$ERRORS
- 改进数量：$IMPROVEMENTS

## 重要发现

### 成功模式
$(grep -h "## 决策" $MEMORY_FILES 2>/dev/null | head -5 || echo "无")

### 需要改进的地方
$(grep -h "错误\|失败" $MEMORY_FILES 2>/dev/null | head -5 || echo "无")

### 学到的经验
$(grep -h "学到了\|学会了\|经验" $MEMORY_FILES 2>/dev/null | head -5 || echo "无")

## 改进建议

1. 继续优化记忆提取算法
2. 加强错误预防机制
3. 定期进行技能学习

## 下一步行动

1. 根据反思更新 MEMORY.md
2. 调整自我改进策略
3. 规划下个周期的重点

---

*此报告由 Self-Evolving Agent 自动生成*
EOF

echo "反思报告已生成: $REFLECT_REPORT" | tee -a "$LOGFILE"

# 4. 更新长期记忆
echo "更新长期记忆..." | tee -a "$LOGFILE"

if [ -f "$WORKSPACE/MEMORY.md" ]; then
    cat >> "$WORKSPACE/MEMORY.md" <<EOF

## 周期反思 $(date +%Y-%m-%d)
**周期：** 过去 $PERIOD 天
**记忆文件：** $MEMORY_COUNT 个
**决策：** $DECISIONS 个
**错误：** $ERRORS 个
**改进：** $IMPROVEMENTS 项
**报告：** $REFLECT_REPORT
EOF
    echo "长期记忆已更新" | tee -a "$LOGFILE"
fi

echo "=== 记忆反思完成 - $(date) ===" | tee -a "$LOGFILE"

# 5. 清理旧反思报告（保留180天）
find "$SELF_IMPROVING_DIR/monitoring" -name "reflect-*.log" -mtime +180 -delete 2>/dev/null || true
find "$SELF_IMPROVING_DIR/monitoring" -name "reflection-*.md" -mtime +180 -delete 2>/dev/null || true

# 6. 写入团队共享记忆（跨 Agent 可见）
echo "写入团队共享记忆..." | tee -a "$LOGFILE"
node -e "
const {AgentContext} = require(process.env.HOME + '/.openclaw/skills/hindsight-memory/lib/multi-agent/index.js');
const ctx = new AgentContext('self-evolving-agent');
ctx.writeShared('observations', \`反思周期：过去 $PERIOD 天\n- 决策：$DECISIONS 个\n- 错误：$ERRORS 个\n- 改进：$IMPROVEMENTS 项\n报告：$REFLECT_REPORT\`, { confidence: 0.8, tags: ['self-improving', '周期反思'] }).then(r => console.log('团队记忆已更新')).catch(e => console.error('写入失败:', e.message));
" 2>&1 | tee -a "$LOGFILE" || true