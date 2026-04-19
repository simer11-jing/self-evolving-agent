# 基准测试文档

## 概述
基准测试用于验证自我改进系统的效果，每次运行后记录关键指标变化。

## 运行基准测试

```bash
cd ~/.openclaw/skills/self-evolving-agent
./scripts/benchmark-runner.sh
```

## 基准指标

| 指标          | 说明                   | 目标    |
|---------------|-----------------------|---------|
| 响应时间      | Agent 平均响应时间     | < 2s    |
| 错误率        | 命令失败比例          | < 5%    |
| 记忆命中率    | 记忆系统检索成功率     | > 70%   |
| 性能评分      | 系统资源使用合理性    | > 80    |

## 测试流程

1. 运行 `benchmark-runner.sh`
2. 比较历史基准
3. 生成报告
4. 分析结果并调整阈值

## 报告格式

报告存储在 `$WORKSPACE/self-improving/benchmarks/` 目录。

---

*Last updated: 2025-04-20*
