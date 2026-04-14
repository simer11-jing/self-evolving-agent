# 更新日志

所有重要的更改都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [2.1.0] - 2026-04-15

### 新增

- ✨ **SQLite 错误存储**
  - 错误记录存入 SQLite 数据库
  - 支持错误模式分析和统计
  - 查询近7天常见错误

- ✨ **记忆系统集成 (memory-integrator.sh)**
  - 与 memory-consolidate 无缝集成
  - 自动检查 MEMORY.md 超限
  - 自动归档过多日志文件

### 改进

- 🔧 **error-analyzer.sh v2.0**
  - 重写为 SQLite 支持版本
  - 新增错误模式分析
  - 自动触发记忆反思（当错误过多时）

### 清理

- 🗑️ 删除 `error-analyzer.sh.bak` 备份文件

---

## [2.0.0] - 2026-04-11

### 新增

- ✨ **基准测试系统** (benchmark-runner.sh)
- ✨ **安全沙箱** (sandbox-validator.sh)
- ✨ **版本控制** - Git 快照 + 回滚
- ✨ **探索模式** - A/B 测试多策略
- ✨ **代码补丁** - 运行时热修补

---

## [1.0.0] - 2026-04-06

### 新增

- 🎉 初始发布
- 🔍 性能监控
- 🐛 错误分析
- ⚡ 优化引擎
- 📚 技能学习

---

_此项目由小爪 (OpenClaw Agent) 创建并维护_ 🐾
