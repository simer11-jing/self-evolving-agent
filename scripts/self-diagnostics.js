#!/usr/bin/env node
/**
 * Self-Diagnostics Module
 * 自我诊断模块 - 实时监控系统健康，自动识别异常并提供修复建议
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync, exec } = require('child_process');
const http = require('http');

const HOME = os.homedir();
const LOG_FILE = path.join(HOME, '.openclaw/skills/self-evolving-agent/logs/diagnostics.log');
const STATE_FILE = path.join(HOME, '.openclaw/skills/self-evolving-agent/logs/daemon-state.json');

// ============================================================================
// Diagnostics Checks
// ============================================================================

const checks = {
  // 1. 进程健康检查
  async processHealth() {
    const issues = [];
    
    // 检查 daemon 进程
    const daemonPid = await getDaemonPid();
    if (!daemonPid) {
      issues.push({ severity: 'critical', message: 'Daemon 进程未运行', fix: 'restart_daemon' });
    } else {
      // 检查进程 CPU/内存
      try {
        const ps = execSync(`ps -p ${daemonPid} -o %cpu,%mem --no-headers`, { encoding: 'utf-8' });
        const [cpu, mem] = ps.trim().split(/\s+/).map(Number);
        if (cpu > 80) issues.push({ severity: 'warning', message: `Daemon CPU 使用率过高: ${cpu}%`, fix: 'investigate_cpu' });
        if (mem > 50) issues.push({ severity: 'warning', message: `Daemon 内存使用率过高: ${mem}%`, fix: 'investigate_memory' });
      } catch (e) {
        issues.push({ severity: 'warning', message: '无法获取进程资源信息', fix: 'check_permissions' });
      }
    }
    
    return { name: '进程健康', issues };
  },

  // 2. 系统资源检查
  async systemResources() {
    const issues = [];
    
    // CPU
    const loadAvg = os.loadavg();
    if (loadAvg[0] > os.cpus().length * 0.8) {
      issues.push({ severity: 'warning', message: `系统负载过高: ${loadAvg[0].toFixed(2)}`, fix: 'reduce_load' });
    }
    
    // 内存
    const freeMem = os.freemem();
    const totalMem = os.totalmem();
    const memUsage = ((totalMem - freeMem) / totalMem * 100).toFixed(1);
    if (memUsage > 85) {
      issues.push({ severity: 'critical', message: `内存使用率过高: ${memUsage}%`, fix: 'free_memory' });
    }
    
    // 磁盘
    try {
      const df = execSync('df -h / | tail -1', { encoding: 'utf-8' });
      const diskUsage = parseInt(df.split(/\s+/)[4]);
      if (diskUsage > 90) {
        issues.push({ severity: 'critical', message: `磁盘使用率过高: ${diskUsage}%`, fix: 'cleanup_disk' });
      } else if (diskUsage > 80) {
        issues.push({ severity: 'warning', message: `磁盘使用率偏高: ${diskUsage}%`, fix: 'plan_cleanup' });
      }
    } catch (e) {
      issues.push({ severity: 'info', message: '无法获取磁盘信息', fix: null });
    }
    
    return { name: '系统资源', issues };
  },

  // 3. Gateway 健康检查
  async gatewayHealth() {
    const issues = [];
    
    try {
      // 检查 Gateway 进程
      const gatewayPid = execSync('pgrep -f "openclaw gateway" | head -1', { encoding: 'utf-8' }).trim();
      if (!gatewayPid) {
        issues.push({ severity: 'critical', message: 'Gateway 进程未运行', fix: 'restart_gateway' });
      } else {
        // 检查 Gateway 端口
        const gatewayConfig = JSON.parse(fs.readFileSync(path.join(HOME, '.openclaw/openclaw.json'), 'utf-8'));
        const port = gatewayConfig.gateway?.port || 28789;
        
        await new Promise((resolve, reject) => {
          const req = http.request({
            hostname: 'localhost',
            port,
            path: '/health',
            method: 'GET',
            timeout: 5000
          }, (res) => {
            if (res.statusCode === 200) resolve();
            else reject(new Error(`Gateway 返回 ${res.statusCode}`));
          });
          req.on('error', reject);
          req.on('timeout', () => reject(new Error('Gateway 响应超时')));
          req.end();
        }).catch(e => {
          issues.push({ severity: 'warning', message: `Gateway 健康检查失败: ${e.message}`, fix: 'check_gateway_logs' });
        });
      }
    } catch (e) {
      issues.push({ severity: 'warning', message: '无法检查 Gateway 状态', fix: 'check_gateway_process' });
    }
    
    return { name: 'Gateway 健康', issues };
  },

  // 4. Cron 任务检查
  async cronTasks() {
    const issues = [];
    
    try {
      const state = JSON.parse(fs.readFileSync(STATE_FILE, 'utf-8'));
      const tasks = state.tasks || {};
      const now = Date.now();
      
      for (const [name, task] of Object.entries(tasks)) {
        if (task.status === 'failed') {
          const age = (now - task.lastRun) / 1000 / 60; // 分钟
          if (age < 60) {
            issues.push({ severity: 'warning', message: `任务 ${name} 最近失败 (${age.toFixed(0)}分钟前)`, fix: 'check_task_logs' });
          }
        }
      }
    } catch (e) {
      // state 文件可能不存在，忽略
    }
    
    return { name: 'Cron 任务', issues };
  },

  // 5. 日志错误分析
  async logErrors() {
    const issues = [];
    
    const logFile = path.join(HOME, '.openclaw/skills/self-evolving-agent/logs/daemon.log');
    if (!fs.existsSync(logFile)) return { name: '日志错误', issues };
    
    try {
      // 读取最近 1000 行日志
      const logs = execSync(`tail -1000 "${logFile}"`, { encoding: 'utf-8' });
      const errorLines = logs.split('\n').filter(l => l.includes('[ERROR]'));
      
      if (errorLines.length > 10) {
        issues.push({ severity: 'warning', message: `最近日志错误过多: ${errorLines.length} 条`, fix: 'analyze_errors' });
        
        // 提取错误模式
        const errorPatterns = {};
        for (const line of errorLines) {
          const match = line.match(/\[ERROR\].*?(\w+Error|ECONNREFUSED|ETIMEDOUT|ENOENT)/);
          if (match) {
            errorPatterns[match[1]] = (errorPatterns[match[1]] || 0) + 1;
          }
        }
        
        const topPattern = Object.entries(errorPatterns).sort((a, b) => b[1] - a[1])[0];
        if (topPattern) {
          issues.push({ severity: 'info', message: `最常见错误: ${topPattern[0]} (${topPattern[1]} 次)`, fix: 'fix_error_pattern' });
        }
      }
    } catch (e) {
      issues.push({ severity: 'info', message: '无法读取日志文件', fix: null });
    }
    
    return { name: '日志错误', issues };
  },

  // 6. 网络连接检查
  async networkConnectivity() {
    const issues = [];
    
    // 检查关键服务
    const services = [
      { name: 'NewAPI', host: '192.168.50.2', port: 3000 },
      { name: 'Chat2API', host: '192.168.50.2', port: 8111 }
    ];
    
    for (const service of services) {
      try {
        await new Promise((resolve, reject) => {
          const socket = require('net').connect(service.port, service.host);
          socket.setTimeout(3000);
          socket.on('connect', () => { socket.destroy(); resolve(); });
          socket.on('timeout', () => { socket.destroy(); reject(new Error('超时')); });
          socket.on('error', reject);
        });
      } catch (e) {
        issues.push({ severity: 'warning', message: `${service.name} 无法连接 (${service.host}:${service.port})`, fix: 'check_service' });
      }
    }
    
    return { name: '网络连接', issues };
  },

  // 7. 记忆系统检查
  async memorySystem() {
    const issues = [];
    
    // 检查 MEMORY.md 容量
    const memoryFile = path.join(HOME, '.openclaw/agents/main/MEMORY.md');
    if (fs.existsSync(memoryFile)) {
      const stats = fs.statSync(memoryFile);
      const lines = execSync(`wc -l "${memoryFile}"`, { encoding: 'utf-8' }).trim().split(' ')[0];
      
      if (lines > 200 || stats.size > 25 * 1024) {
        issues.push({ severity: 'warning', message: `MEMORY.md 接近容量限制 (${lines}行/${(stats.size/1024).toFixed(1)}KB)`, fix: 'consolidate_memory' });
      }
    }
    
    // 检查向量索引是否存在且新鲜
    const indexFile = path.join(HOME, '.openclaw/agents/main/.memory-index.json');
    if (fs.existsSync(indexFile)) {
      const indexAge = (Date.now() - fs.statSync(indexFile).mtimeMs) / 1000 / 3600; // 小时
      if (indexAge > 48) {
        issues.push({ severity: 'info', message: `向量索引已过期 (${indexAge.toFixed(0)}小时前)`, fix: 'rebuild_index' });
      }
    } else {
      issues.push({ severity: 'warning', message: '向量索引不存在', fix: 'build_index' });
    }
    
    return { name: '记忆系统', issues };
  }
};

// ============================================================================
// Auto-Fix Actions
// ============================================================================

const autoFixes = {
  restart_daemon() {
    console.log('🔄 自动重启 daemon...');
    execSync('pkill -f self-evolving-daemon.js', { stdio: 'ignore' });
    execSync('nohup node ~/.openclaw/skills/self-evolving-agent/self-evolving-daemon.js >> ~/.openclaw/skills/self-evolving-agent/logs/daemon.log 2>&1 &');
    return 'Daemon 已重启';
  },

  restart_gateway() {
    console.log('🔄 自动重启 Gateway...');
    execSync('openclaw gateway restart', { stdio: 'inherit' });
    return 'Gateway 已重启';
  },

  cleanup_disk() {
    console.log('🧹 清理磁盘...');
    // 清理旧日志
    execSync('find ~/.openclaw -name "*.log" -mtime +30 -delete', { stdio: 'ignore' });
    execSync('find /tmp -name "*.tmp" -mtime +7 -delete', { stdio: 'ignore' });
    // 清理 sessions
    execSync('rm -rf /data/sessions/*', { stdio: 'ignore' });
    return '磁盘已清理';
  },

  consolidate_memory() {
    console.log('📚 整理记忆...');
    execSync('node ~/.openclaw/skills/hindsight-memory/scripts/memory-consolidate.js', { stdio: 'inherit' });
    return '记忆已整理';
  },

  build_index() {
    console.log('🔍 建立向量索引...');
    execSync('cd ~/.openclaw/skills/hindsight-memory && node scripts/memory-semantic.js 索引', { stdio: 'inherit' });
    return '向量索引已建立';
  }
};

// ============================================================================
// Helpers
// ============================================================================

async function getDaemonPid() {
  try {
    const pid = execSync('pgrep -f "self-evolving-daemon.js"', { encoding: 'utf-8' }).trim().split('\n')[0];
    return pid ? parseInt(pid) : null;
  } catch (e) {
    return null;
  }
}

function log(message) {
  const timestamp = new Date().toISOString();
  const line = `[${timestamp}] ${message}\n`;
  fs.appendFileSync(LOG_FILE, line);
  console.log(message);
}

// ============================================================================
// Main
// ============================================================================

async function runDiagnostics(options = {}) {
  const { autoFix = false, silent = false } = options;
  
  const results = [];
  let totalIssues = 0;
  const criticalIssues = [];
  
  // 运行所有检查
  for (const [key, check] of Object.entries(checks)) {
    try {
      const result = await check();
      results.push(result);
      totalIssues += result.issues.length;
      
      result.issues.forEach(issue => {
        if (issue.severity === 'critical') {
          criticalIssues.push({ ...issue, category: result.name });
        }
      });
      
      if (!silent) {
        const status = result.issues.length === 0 ? '✅' : 
                       result.issues.some(i => i.severity === 'critical') ? '❌' : '⚠️';
        console.log(`${status} ${result.name}: ${result.issues.length} 个问题`);
      }
    } catch (e) {
      results.push({ name: key, issues: [{ severity: 'error', message: e.message, fix: null }] });
    }
  }
  
  // 自动修复
  const fixed = [];
  if (autoFix && criticalIssues.length > 0) {
    if (!silent) console.log('\n🔧 执行自动修复...');
    
    for (const issue of criticalIssues) {
      if (issue.fix && autoFixes[issue.fix]) {
        try {
          const result = autoFixes[issue.fix]();
          fixed.push({ issue: issue.message, fix: result });
          if (!silent) console.log(`  ✅ ${issue.message} → ${result}`);
        } catch (e) {
          if (!silent) console.log(`  ❌ ${issue.message} 修复失败: ${e.message}`);
        }
      }
    }
  }
  
  // 生成报告
  const report = {
    timestamp: new Date().toISOString(),
    summary: {
      totalChecks: results.length,
      totalIssues,
      criticalIssues: criticalIssues.length,
      autoFixed: fixed.length
    },
    results,
    criticalIssues,
    fixed
  };
  
  // 保存报告
  const reportFile = path.join(HOME, '.openclaw/skills/self-evolving-agent/logs/diagnostics-report.json');
  fs.writeFileSync(reportFile, JSON.stringify(report, null, 2));
  
  if (!silent) {
    console.log(`\n📊 诊断完成: ${totalIssues} 个问题, ${criticalIssues.length} 个严重, ${fixed.length} 个已修复`);
  }
  
  return report;
}

// CLI
if (require.main === module) {
  const args = process.argv.slice(2);
  const autoFix = args.includes('--fix') || args.includes('-f');
  const silent = args.includes('--silent') || args.includes('-s');
  
  runDiagnostics({ autoFix, silent })
    .then(report => {
      if (!silent) {
        console.log('\n详细报告: ~/.openclaw/skills/self-evolving-agent/logs/diagnostics-report.json');
      }
      process.exit(report.criticalIssues.length > 0 ? 1 : 0);
    })
    .catch(e => {
      console.error('❌ 诊断失败:', e.message);
      process.exit(2);
    });
}

module.exports = { runDiagnostics, checks, autoFixes };
