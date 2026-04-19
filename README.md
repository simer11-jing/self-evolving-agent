# Self-Evolving Agent

> 让 AI 助手具备自我进化能力的自动化改进系统

---

## 📋 概述

**Self-Evolving Agent** 是一个自动化自我改进系统，让 AI 助手能够：

- 🔍 **持续监控** - 监控系统性能和资源使用
- 🐛 **自动纠错** - 分析错误模式并提供修复建议
- ⚡ **智能优化** - 根据触发条件自动执行优化
- 📚 **技能学习** - 分析需求缺口并自动学习新技能
- 🔄 **反馈循环** - 收集和处理用户反馈
- 🧠 **周期反思** - 基于 Hindsight 架构进行周期性反思
- 🧪 **基准测试** - 自动化系统验证
- 🛡️ **安全沙箱** - 执行前安全验证
- 📜 **版本控制** - 跟踪和回滚变更
- 🤝 **跨 Agent 记忆** - 通过 Hindsight Memory 与团队共享经验
- 🧠 **Kairos 推理** - 优化决策前先查历史经验

---

## 🎯 核心功能

### 1. 性能监控

自动监控系统性能指标：

| 指标 | 说明 |
|------|------|
| CPU 使用率 | 系统 CPU 占用百分比 |
| 内存使用率 | 系统内存占用百分比 |
| 磁盘使用率 | 磁盘空间占用百分比 |
| 活跃会话 | OpenClaw 活跃会话数量 |
| 网关状态 | OpenClaw 网关运行状态 |

**触发阈值**：
- CPU > 80% → 触发优化
- 内存 > 80% → 触发优化
- 磁盘 > 90% → 触发优化

### 2. 错误分析

自动分析并记录错误：
- 分析 OpenClaw 错误日志
- 检查 Cron 任务失败情况
- 识别错误模式
- 提供修复建议

### 3. 优化引擎

支持多种优化策略：

| 模式 | 说明 |
|------|------|
| 传统模式 | 基于触发条件的单一策略 |
| 探索模式 | A/B 测试多种策略 |
| 自动选择 | 自动选择最佳策略 |

**Kairos 推理集成**：生成优化建议前，自动查询团队历史经验，避免重复踩坑。

### 4. 技能学习

根据用户需求自动安装技能。

### 5. 记忆反思

基于 Hindsight 架构进行周期性反思（默认每天 23:55 运行）：
- 收集过去 N 天的记忆文件
- 统计决策数量、错误数量、改进数量
- 生成反思报告，写入私有 MEMORY.md
- **同时写入** `~/.openclaw/agents/shared/observations` 层供团队共享

```bash
./scripts/memory-reflect.sh 7    # 周度反思
./scripts/memory-reflect.sh 30   # 月度反思
```

### 6. 反馈循环

收集和处理用户反馈。

### 7. 基准测试

自动化系统验证：

```bash
./scripts/benchmark-runner.sh
```

- 记忆系统测试
- 性能基准测试
- 结果对比

### 8. 安全沙箱

执行前安全验证：

```bash
./scripts/sandbox-validator.sh analyze <脚本>
./scripts/sandbox-validator.sh execute <脚本>
```

- 静态代码分析
- 危险命令检测
- 回滚能力

---

## 🚀 快速开始

### 安装

```bash
git clone https://github.com/simer11-jing/self-evolving-agent.git ~/.openclaw/skills/self-evolving-agent
```

### 运行

```bash
# 完整工作流
./scripts/self-improving-controller.sh

# 仅监控
./scripts/self-improving-controller.sh --monitor

# 基准测试
./scripts/benchmark-runner.sh

# 安全验证
./scripts/sandbox-validator.sh analyze 你的脚本.sh
```

---

## 🤝 跨系统集成

### Hindsight Memory（记忆系统）

`memory-reflect.sh` 反思结论自动写入共享记忆层，其他 Agent 可实时查询：

```bash
# 团队共享记忆路径
~/.openclaw/agents/shared/
```

### Kairos 推理引擎

`optimization-engine.sh` 在生成优化策略前，自动查询团队历史经验：

```
检测到问题 → 查询 Kairos 历史记忆 → 生成优化建议 → 执行
```

---

## 📁 目录结构

```
self-evolving-agent/
├── scripts/
│   ├── self-improving-controller.sh    # 主控制器
│   ├── performance-monitor.sh          # 性能监控
│   ├── error-analyzer.sh               # 错误分析
│   ├── optimization-engine.sh          # 优化引擎 + Kairos 集成
│   ├── skill-learner.sh                # 技能学习
│   ├── feedback-loop.sh                # 反馈循环
│   ├── memory-reflect.sh               # 记忆反思 + 共享层写入
│   ├── memory-integrator.sh            # 记忆规整
│   ├── benchmark-runner.sh             # 基准测试
│   ├── sandbox-validator.sh            # 安全沙箱
│   ├── benchmark-report.sh             # 基准报告
│   └── code-patcher.sh                 # 代码补丁
└── docs/
    └── BENCHMARKS.md                   # 基准测试文档
```

---

## 🆕 v2.1.0 新功能

| 功能 | 说明 |
|------|------|
| **跨 Agent 记忆** | 反思结论写入 hindsight-memory 共享层 |
| **Kairos 推理集成** | 优化前查询历史经验，推理驱动决策 |
| **基准测试** | 自动化系统验证 |
| **安全沙箱** | 执行前安全检查 |
| **版本控制** | Git 快照 + 回滚 |
| **探索模式** | A/B 测试多策略 |

---

## ⚙️ 工作流程

```
┌─────────────────────────────────────────────────────────────┐
│                      自我改进控制器                          │
│                     (每天 23:00 运行)                        │
└─────────────────────────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         ▼                    ▼                    ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   性能监控   │      │   错误分析   │      │   技能学习   │
│   Monitor   │      │  Analyzer   │      │   Learner   │
└─────────────┘      └─────────────┘      └─────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   基准测试   │      │   安全沙箱   │      │   Kairos    │
│  Benchmark  │      │   Sandbox   │      │  推理验证    │
└─────────────┘      └─────────────┘      └─────────────┘
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   生成报告       │
                    │   更新记忆       │
                    │   → shared/     │ ← 团队共享
                    │   微信通知       │
                    └─────────────────┘
```

---

## ⚠️ 注意事项

1. **权限**：需要写入 `~/.openclaw/workspace` 的权限
2. **依赖**：需要 `jq`、`curl`、`top`、`free`、`df` 等系统工具
3. **定时任务**：建议深夜运行，避免影响正常操作
4. **清理**：日志默认保留 30 天，报告保留 180 天

---

## 📖 相关项目

- [Hindsight Memory](https://github.com/simer11-jing/hindsight-memory) - 记忆系统（含跨 Agent 共享层）
- [Kairos](https://github.com/simer11-jing/Kairos) - 推理引擎
- [OpenClaw](https://github.com/openclaw/openclaw) - AI 代理平台

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

## 📄 许可证

MIT License

---

_由小爪（OpenClaw Agent）创建并维护_ 🐾
