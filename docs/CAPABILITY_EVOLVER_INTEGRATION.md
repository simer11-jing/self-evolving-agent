# Capability Evolver 集成说明

## 概述

Capability Evolver 已集成到 Self-Evolving Agent 的性能监控流程中，作为**第一层快速健康检查**。

## 架构

```
┌─────────────────────────────────────────────────────────────┐
│              performance-monitor.sh (每小时运行)             │
└─────────────────────────────────────────────────────────────┘
                          │
         ┌────────────────┴────────────────┐
         ▼                                 ▼
┌─────────────────────┐        ┌─────────────────────┐
│  Capability Evolver │        │   系统资源检查       │
│   (快速健康评分)     │        │  CPU/内存/磁盘       │
│   $0.03/次,<100ms   │        │                     │
└─────────────────────┘        └─────────────────────┘
         │                                 │
         └────────────────┬────────────────┘
                          │ 健康评分 < 70 或资源超标
                          ▼
              ┌─────────────────────┐
              │   optimization-engine.sh  │
              │     (深度分析)            │
              │   - Kairos 推理          │
              │   - LLM 语义分析         │
              │   - 多策略优化           │
              └─────────────────────┘
```

## 配置

1. 获取 ClawHub API Key:
   ```bash
   # 访问 https://claw0x.com 注册并获取 API Key
   ```

2. 配置环境变量:
   ```bash
   # 方式 1: 环境变量
   export CLAW0X_API_KEY=your_api_key_here
   
   # 方式 2: 配置文件
   vim ~/.openclaw/skills/self-evolving-agent/config/capability-evolver.env
   ```

3. 验证配置:
   ```bash
   ~/.openclaw/skills/self-evolving-agent/scripts/capability-evolver-integration.sh
   ```

## 使用

### 自动运行（推荐）
性能监控脚本每小时自动运行，Capability Evolver 作为第一层检查自动执行：
```bash
# 已集成到 performance-monitor.sh
# 无需手动操作
```

### 手动运行
```bash
# 设置 API Key
export CLAW0X_API_KEY=your_key

# 运行健康检查
~/.openclaw/skills/self-evolving-agent/scripts/capability-evolver-integration.sh
```

### 集成到 Cron
```bash
# 每 5 分钟快速健康检查
*/5 * * * * CLAW0X_API_KEY=xxx /home/jinghao/.openclaw/skills/self-evolving-agent/scripts/capability-evolver-integration.sh
```

## 输出

### 控制台输出
```
[2026-04-30 13:00:00] 收集最近 1 小时的运行日志...
[2026-04-30 13:00:01] 收集到 15 条日志记录
[2026-04-30 13:00:01] 调用 Capability Evolver API...
[2026-04-30 13:00:02] 健康评分: 85/100
[2026-04-30 13:00:02] 检测到模式: 2 个
[2026-04-30 13:00:02] 改进建议: 3 条
```

### 环境变量输出（供其他脚本使用）
```
HEALTH_SCORE=85
PATTERNS_COUNT=2
RECOMMENDATIONS_COUNT=3
RESPONSE_FILE=/home/jinghao/.openclaw/workspace/self-improving/capability-evolver/response-20260430-130002.json
```

### 触发文件
健康评分低于 70 时，创建触发文件：
```
~/.openclaw/workspace/self-improving/optimizations/trigger.txt
内容:
  low_health_score:65
  capability_evolver_alert
  CPU=45.2,MEM=62.3,DISK=78
```

## 成本

- **每次调用**: $0.03
- **失败免费**: API 调用失败不收费
- **预估月成本**: ~$2.16 (每小时一次，30天)

## 优势

| 维度 | Capability Evolver | 传统监控 |
|------|-------------------|---------|
| **速度** | <100ms | 秒级 |
| **确定性** | 可复现 | 依赖 LLM |
| **成本** | 固定 $0.03 | Token 消耗波动 |
| **输出** | 结构化 | 自然语言 |

## 故障排查

### API 调用失败
```bash
# 检查 API Key
echo $CLAW0X_API_KEY

# 测试连接
curl -s https://api.claw0x.com/v1/call \
  -H "Authorization: Bearer $CLAW0X_API_KEY" \
  -d '{"skill":"capability-evolver","input":{"action":"status"}}'
```

### 无日志数据
脚本会自动使用系统基础指标作为最小数据集。

### 跳过检查
如果未配置 `CLAW0X_API_KEY`，脚本会优雅降级并跳过 Capability Evolver 分析。

## 相关文件

- **集成脚本**: `scripts/capability-evolver-integration.sh`
- **配置文件**: `config/capability-evolver.env`
- **性能监控**: `scripts/performance-monitor.sh`
- **优化引擎**: `scripts/optimization-engine.sh`
- **日志目录**: `~/.openclaw/workspace/self-improving/capability-evolver/`

## 更新日志

- **2026-04-30**: 初始集成，添加第一层快速健康检查
