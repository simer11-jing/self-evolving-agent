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

---

## 🎯 核心功能

### 1. 性能监控

自动监控系统性能指标，动态调整阈值。

### 2. 错误分析

自动分析并记录错误，提供修复建议。

### 3. 优化引擎

支持传统模式和开放探索模式（A/B 测试）。

### 4. 基准测试 (NEW)

自动化系统验证：

```bash
./scripts/benchmark-runner.sh
```

### 5. 安全沙箱 (NEW)

执行前安全验证：

```bash
./scripts/sandbox-validator.sh analyze <script>
./scripts/sandbox-validator.sh execute <script>
```

### 6. 技能学习

根据用户需求自动安装技能。

### 7. 反馈循环

收集和处理用户反馈。

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
```

---

## 📁 目录结构

```
self-evolving-agent/
├── scripts/
│   ├── self-improving-controller.sh
│   ├── performance-monitor.sh
│   ├── error-analyzer.sh
│   ├── optimization-engine.sh      # 已增强
│   ├── skill-learner.sh
│   ├── feedback-loop.sh
│   ├── memory-reflect.sh
│   ├── benchmark-runner.sh         # NEW
│   ├── sandbox-validator.sh        # NEW
│   ├── benchmark-report.sh         # NEW
│   └── code-patcher.sh             # NEW
└── docs/
    └── BENCHMARKS.md               # NEW
```

---

## v2.0.0 新功能

| 功能 | 说明 |
|------|------|
| Benchmark 测试 | 自动化系统验证 |
| 安全沙箱 | 执行前安全检查 |
| 版本控制 | Git 快照 + 回滚 |
| 探索模式 | A/B 测试多策略 |
| 代码补丁 | 运行时热修补 |

---

## ⚙️ 配置

### 定时任务

```bash
crontab -e
# 每天 23:00 运行
0 23 * * * /path/to/self-evolving-agent/scripts/self-improving-controller.sh
```

### 环境变量

```bash
# 开启探索模式
export EXPLORATION_MODE=true

# 自定义工作目录
export WORKSPACE=~/.openclaw/workspace
```

---

## 📊 性能评分

| 评分 | 状态 |
|------|------|
| 90-100 | 优秀 |
| 70-89 | 良好 |
| 50-69 | 一般 |
| 0-49 | 需优化 |

---

## 🔧 故障排除

### 优化失败

1. 检查系统日志
2. 验证脚本可执行权限
3. 使用沙箱模式测试

### 基准测试失败

1. 检查依赖是否安装
2. 查看测试日志
3. 手动运行单个测试

---

## 📖 参考

- [Hindsight Memory](https://github.com/simer11-jing/hindsight-memory)
- [OpenClaw 文档](https://docs.openclaw.ai)

---

## 🤝 贡献

欢迎提交 Issue 和 PR！

---

## 📄 许可证

MIT License

---

_由小爪（OpenClaw Agent）创建并维护_ 🐾