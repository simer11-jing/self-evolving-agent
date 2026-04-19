# 更新日志

所有重要的更改都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [2.2.0] - 2026-04-20

### 新增

- ✨ **竞彩定时推送体系**
  - `jingcai-morning.sh` (10:00) - 早盘预测，五大联赛焦点预览
  - `jingcai-review.sh` (12:00) - 午间复盘，昨日胜率统计
  - `jingcai-afternoon.sh` (15:00) - 午后修正，赔率异常检测
  - `jingcai-evening.sh` (21:00) - 晚盘报告，今日完整分析
  - 所有脚本直发飞书群

- ✨ **竞彩赛果自动抓取** (`jingcai-results-fetcher.sh`)
  - sporttery.cn 官方 API，每12小时自动抓取
  - 自动去重写入 betting-results.md

- ✨ **Daemon 崩溃重启飞书通知**
  - `checkCrashRestart()` 检测异常退出
  - 心跳机制（每5分钟写状态文件）
  - 崩溃后自动发送飞书通知

- ✨ **日志 gzip 压缩轮转**
  - 10MB 触发压缩，保留 maxFiles*2 个旧日志
  - 减少磁盘占用

- ✨ **memory-compact 调度**
  - 每3天自动调用 hindsight-memory compact
  - 保持记忆文件健康

- ✨ **skill-learner 高级投注模式**
  - 连胜/连负识别
  - 高赔偏好检测（>3.5）
  - 主客场偏差统计
  - 各联赛独立胜率

### 修复

- 🐛 **硬编码路径** - `/home/jinghao` → `$HOME`/`process.env.HOME`
  - self-evolving-daemon.js: 5处
  - kairos-learner.py: 5处
  - memory-reflect.sh: 1处

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
