#!/bin/bash
# 自我诊断脚本 - 由 daemon 调度
# 每30分钟运行一次

SCRIPT_DIR="$HOME/.openclaw/skills/self-evolving-agent"

cd "$SCRIPT_DIR"

# 运行 Node.js 诊断模块
node -e "
const { runDiagnostics } = require('./scripts/self-diagnostics.js');

runDiagnostics({ autoFix: true, silent: false })
  .then(report => {
    const { totalIssues, criticalIssues, autoFixed } = report.summary;
    
    if (criticalIssues > 0) {
      console.log('⚠️ 发现', criticalIssues, '个严重问题');
      process.exit(1);
    } else if (autoFixed > 0) {
      console.log('✅ 已自动修复', autoFixed, '个问题');
      process.exit(0);
    } else {
      console.log('✅ 系统健康');
      process.exit(0);
    }
  })
  .catch(e => {
    console.error('诊断失败:', e.message);
    process.exit(2);
  });
"
