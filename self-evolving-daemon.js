#!/usr/bin/env node
/**
 * Self-Evolving Agent Daemon
 * 
 * 替代 crontab 模式的自包含 daemon，实现：
 * - 内置调度器（替代 crontab）
 * - 组件管理器（执行脚本）
 * - 状态持久化
 * - 优雅退出
 */

const fs = require('fs');
const path = require('path');
const { spawn, execSync } = require('child_process');

// ============================================================================
// 配置
// ============================================================================

const CONFIG = {
  pidFile: '/tmp/self-evolving-daemon.pid',
  stateFile: path.join(process.env.HOME || os.homedir(), '.openclaw/workspace/self-improving/daemon-state.json'),
  crashStateFile: path.join(process.env.HOME || os.homedir(), '.openclaw/workspace/self-improving/daemon-crash-state.json'),
  logDir: path.join(process.env.HOME || os.homedir(), '.openclaw/workspace/self-improving'),
  scriptsDir: path.join(process.env.HOME || os.homedir(), '.openclaw/skills/self-evolving-agent/scripts'),
  statusIntervalMs: 60 * 60 * 1000, // 每小时打印状态
  heartbeatIntervalMs: 5 * 60 * 1000, // 每5分钟更新心跳
};

// 调度表配置
const SCHEDULE = [
  { name: 'performance-monitor', intervalMs: 6 * 60 * 60 * 1000 },      // 6小时
  { name: 'error-analyzer', intervalMs: 24 * 60 * 60 * 1000 },         // 24小时
  { name: 'optimization-engine', intervalMs: 24 * 60 * 60 * 1000 },    // 24小时
  { name: 'feedback-loop', intervalMs: 24 * 60 * 60 * 1000 },          // 24小时
  { name: 'memory-integrator', intervalMs: 24 * 60 * 60 * 1000 },      // 24小时
  { name: 'jingcai-monitor', intervalMs: 24 * 60 * 60 * 1000 },       // 竞彩监控（每天晚6点）
  { name: 'jingcai-analyzer', intervalMs: 24 * 60 * 60 * 1000 },      // 竞彩分析（每天晚7点）
  { name: 'jingcai-results-fetcher', intervalMs: 12 * 60 * 60 * 1000 }, // 赛果抓取（每天早9点）
  { name: 'jingcai-learner', intervalMs: 7 * 24 * 60 * 60 * 1000 },     // 竞彩学习（每周一次）
  { name: 'memory-compact', intervalMs: 3 * 24 * 60 * 60 * 1000 },       // 记忆压缩（每3天）
  { name: 'skill-learner', intervalMs: 7 * 24 * 60 * 60 * 1000 },      // 7天
  { name: 'memory-reflect', intervalMs: 7 * 24 * 60 * 60 * 1000, dayOfWeek: 0 }, // 7天，周日触发
];

// ============================================================================
// Logger
// ============================================================================

class Logger {
  constructor(logDir, maxSizeMB = 10, maxFiles = 7) {
    this.logDir = logDir;
    this.maxSize = maxSizeMB * 1024 * 1024;
    this.maxFiles = maxFiles;
    this.currentLogFile = null;
    this.currentLogDate = null;
    this.currentSize = 0;
    
    // 初始化时检查当前日志文件大小
    this._ensureLogFile();
  }

  _ensureLogFile() {
    const logFile = this.getLogFilePath();
    if (fs.existsSync(logFile)) {
      const stat = fs.statSync(logFile);
      this.currentSize = stat.size;
      if (this.currentSize > this.maxSize) {
        this._rotate();
      }
    }
  }

  getLogFilePath() {
    const date = new Date().toISOString().slice(0, 10);
    if (date !== this.currentLogDate) {
      this.currentLogDate = date;
      this.currentLogFile = path.join(this.logDir, `daemon-${date}.log`);
      // 日期变化时重置大小并检查
      this._ensureLogFile();
    }
    return this.currentLogFile;
  }

  _rotate() {
    if (!this.currentLogFile || !fs.existsSync(this.currentLogFile)) {
      return;
    }
    
    // 轮转：重命名旧文件，添加时间戳
    const timestamp = Date.now();
    const rotated = this.currentLogFile.replace('.log', `-${timestamp}.log`);
    try {
      fs.renameSync(this.currentLogFile, rotated);
    } catch (e) {
      // 忽略重命名错误
    }
    this.currentSize = 0;
    
    // 压缩旧日志 (gzip)
    this._compressLog(rotated);
    
    // 清理过期文件 (支持 .log 和 .log.gz)
    try {
      const files = fs.readdirSync(this.logDir)
        .filter(f => f.startsWith('daemon-') && (f.endsWith('.log') || f.endsWith('.log.gz')))
        .map(f => ({ name: f, time: fs.statSync(path.join(this.logDir, f)).mtime }))
        .sort((a, b) => b.time - a.time);
      
      // maxFiles * 2 因为每个日志可能有 .log 和 .log.gz 两个版本
      for (const f of files.slice(this.maxFiles * 2)) {
        fs.unlinkSync(path.join(this.logDir, f.name));
      }
    } catch (e) {
      // 忽略清理错误
    }
  }

  _compressLog(logFile) {
    if (!fs.existsSync(logFile)) return;
    
    try {
      // 检查 gzip 是否可用
      execSync('which gzip', { stdio: 'ignore' });
      execSync(`gzip -9 "${logFile}"`, { stdio: 'ignore' });
    } catch (e) {
      // gzip 不可用，静默跳过压缩
    }
  }

  log(level, message) {
    const timestamp = new Date().toISOString();
    const logLine = `[${timestamp}] [${level}] ${message}\n`;
    
    // 同时输出到控制台和文件
    process.stdout.write(logLine);
    
    try {
      const logFile = this.getLogFilePath();
      // 检查是否需要轮转
      if (this.currentSize > this.maxSize) {
        this._rotate();
      }
      fs.appendFileSync(logFile, logLine);
      this.currentSize += Buffer.byteLength(logLine);
    } catch (e) {
      // 忽略日志写入错误
    }
  }

  info(message) { this.log('INFO', message); }
  error(message) { this.log('ERROR', message); }
  warn(message) { this.log('WARN', message); }
  debug(message) { this.log('DEBUG', message); }
}

// ============================================================================
// StateStore
// ============================================================================

class StateStore {
  constructor(stateFile) {
    this.stateFile = stateFile;
    this.state = this.load();
  }

  load() {
    try {
      if (fs.existsSync(this.stateFile)) {
        return JSON.parse(fs.readFileSync(this.stateFile, 'utf8'));
      }
    } catch (e) {
      // 忽略错误，返回空状态
    }
    return { tasks: {}, startTime: Date.now() };
  }

  save() {
    try {
      fs.writeFileSync(this.stateFile, JSON.stringify(this.state, null, 2));
    } catch (e) {
      console.error('Failed to save state:', e.message);
    }
  }

  getTaskState(name) {
    return this.state.tasks[name] || { lastRun: 0, status: 'never', runs: 0 };
  }

  setTaskState(name, status, error = null) {
    this.state.tasks[name] = {
      lastRun: Date.now(),
      status,
      error,
      runs: (this.state.tasks[name]?.runs || 0) + 1,
    };
    this.save();
  }
}

// ============================================================================
// ComponentManager
// ============================================================================

class ComponentManager {
  constructor(scriptsDir, stateStore, logger) {
    this.scriptsDir = scriptsDir;
    this.stateStore = stateStore;
    this.logger = logger;
    this.runningScripts = new Set();
  }

  async run(name) {
    if (this.runningScripts.has(name)) {
      this.logger.warn(`[${name}] 已在运行中，跳过`);
      return { success: false, reason: 'already_running' };
    }

    this.runningScripts.add(name);
    this.logger.info(`[${name}] 开始执行...`);
    const startTime = Date.now();

    try {
      await this.runScript(name);
      const duration = Date.now() - startTime;
      this.stateStore.setTaskState(name, 'success');
      this.logger.info(`[${name}] 完成，耗时 ${(duration / 1000).toFixed(1)}s`);
      return { success: true, duration };
    } catch (e) {
      const duration = Date.now() - startTime;
      this.stateStore.setTaskState(name, 'failed', e.message);
      this.logger.error(`[${name}] 失败: ${e.message}`);
      return { success: false, error: e.message, duration };
    } finally {
      this.runningScripts.delete(name);
    }
  }

  runScript(name) {
    const scriptPath = path.join(this.scriptsDir, `${name}.sh`);
    
    if (!fs.existsSync(scriptPath)) {
      return Promise.reject(new Error(`脚本不存在: ${scriptPath}`));
    }

    return new Promise((resolve, reject) => {
      const child = spawn('bash', [scriptPath], {
        env: {
          ...process.env,
          SKILL_DIR: path.dirname(this.scriptsDir),
          COMPONENT_NAME: name,
        },
        cwd: this.scriptsDir,
      });

      let stdout = '';
      let stderr = '';

      child.stdout.on('data', (data) => {
        const output = data.toString();
        stdout += output;
        // 实时打印输出
        output.split('\n').filter(l => l).forEach(line => {
          this.logger.debug(`[${name}] ${line}`);
        });
      });

      child.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      child.on('close', (code) => {
        if (code === 0) {
          resolve({ stdout, stderr });
        } else {
          reject(new Error(`退出码 ${code}: ${stderr.slice(-200)}`));
        }
      });

      child.on('error', (e) => {
        reject(new Error(`进程错误: ${e.message}`));
      });
    });
  }
}

// ============================================================================
// Scheduler
// ============================================================================

class Scheduler {
  constructor(componentManager, stateStore, logger) {
    this.componentManager = componentManager;
    this.stateStore = stateStore;
    this.logger = logger;
    this.tasks = new Map();
    this.timers = new Map();
    this.running = false;
  }

  add(name, intervalMs, options = {}) {
    this.tasks.set(name, { name, intervalMs, ...options });
  }

  start() {
    if (this.running) return;
    this.running = true;

    this.logger.info('调度器启动');
    this.logger.info(`已注册 ${this.tasks.size} 个任务`);

    for (const [name, task] of this.tasks) {
      this.scheduleNext(task);
    }
  }

  stop() {
    this.running = false;
    for (const timer of this.timers.values()) {
      clearTimeout(timer);
    }
    this.timers.clear();
    this.logger.info('调度器停止');
  }

  scheduleNext(task) {
    if (!this.running) return;

    const now = Date.now();
    const taskState = this.stateStore.getTaskState(task.name);
    const lastRun = taskState.lastRun || 0;
    
    let nextRun;
    
    // 特殊处理：周日触发
    if (task.dayOfWeek !== undefined) {
      nextRun = this.calculateNextDayOfWeekRun(task.dayOfWeek, lastRun, task.intervalMs);
    } else {
      // 常规间隔调度
      nextRun = lastRun + task.intervalMs;
      if (nextRun <= now) {
        nextRun = now + 1000; // 1秒后执行
      }
    }

    const delay = Math.max(0, nextRun - now);
    
    this.logger.info(`[${task.name}] 下次运行: ${new Date(nextRun).toISOString()} (${delay > 60000 ? Math.round(delay/60000) + '分钟后' : Math.round(delay/1000) + '秒后'})`);

    const timer = setTimeout(async () => {
      if (!this.running) return;
      
      await this.componentManager.run(task.name);
      
      // 调度下次运行
      this.scheduleNext(task);
    }, delay);

    this.timers.set(task.name, timer);
  }

  calculateNextDayOfWeekRun(targetDayOfWeek, lastRun, intervalMs) {
    const now = Date.now();
    
    // 如果从未运行过，找到下一个目标日期
    if (!lastRun) {
      return this.findNextDayOfWeek(targetDayOfWeek, now);
    }

    // 如果上次运行是7天前（或更久），立即调度
    if (now - lastRun >= intervalMs) {
      return this.findNextDayOfWeek(targetDayOfWeek, now);
    }

    // 否则，从上次运行时间计算下一个目标日期
    return this.findNextDayOfWeek(targetDayOfWeek, lastRun + intervalMs);
  }

  findNextDayOfWeek(targetDayOfWeek, startTime) {
    const date = new Date(startTime);
    
    // 找到下一个目标日期（最多找14天）
    for (let i = 0; i < 14; i++) {
      date.setDate(date.getDate() + 1);
      if (date.getDay() === targetDayOfWeek) {
        // 设置在当天的凌晨2点执行
        date.setHours(2, 0, 0, 0);
        return date.getTime();
      }
    }
    
    // 兜底：7天后
    return startTime + 7 * 24 * 60 * 60 * 1000;
  }

  nextRun(name) {
    const task = this.tasks.get(name);
    if (!task) return null;
    
    const taskState = this.stateStore.getTaskState(name);
    const lastRun = taskState.lastRun || 0;
    
    if (task.dayOfWeek !== undefined) {
      return this.calculateNextDayOfWeekRun(task.dayOfWeek, lastRun, task.intervalMs);
    }
    
    return lastRun + task.intervalMs;
  }
}

// ============================================================================
// 崩溃重启检测
// ============================================================================

function processKillCheck(pid) {
  try {
    process.kill(pid, 0);
    return true;  // 进程存在
  } catch {
    return false; // 进程不存在
  }
}

function sendFeishuNotification(text) {
  try {
    const pushScript = path.join(process.env.HOME, '.openclaw', 'agents', 'main', 'send_feishu.js');
    if (fs.existsSync(pushScript)) {
      execSync(`node "${pushScript}" "${text.replace(/"/g, '\\"')}"`, { stdio: 'ignore' });
    }
  } catch (e) {
    // 飞书通知失败不阻断启动
    console.error('飞书通知失败:', e.message);
  }
}

function checkCrashRestart(logger) {
  const stateFile = CONFIG.crashStateFile;
  let state = {};
  
  if (fs.existsSync(stateFile)) {
    try {
      state = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
    } catch (e) {
      // 忽略解析错误
    }
  }
  
  const wasRunning = state.status === 'running';
  const lastPid = state.pid;
  const abnormal = wasRunning && lastPid && !processKillCheck(lastPid);
  
  if (abnormal) {
    const msg = `🚨 Daemon 异常重启

上次运行状态: ${state.status}
PID: ${lastPid}
崩溃时间: ${state.lastHeartbeat || '未知'}
重启时间: ${new Date().toISOString()}`;
    
    if (logger) {
      logger.warn('检测到异常重启，发送飞书通知...');
    }
    sendFeishuNotification(msg);
  }
  
  // 更新状态
  state.status = 'running';
  state.pid = process.pid;
  state.startTime = new Date().toISOString();
  state.lastHeartbeat = new Date().toISOString();
  
  try {
    fs.writeFileSync(stateFile, JSON.stringify(state, null, 2));
  } catch (e) {
    // 忽略写入错误
  }
}

function updateHeartbeat() {
  const stateFile = CONFIG.crashStateFile;
  try {
    if (fs.existsSync(stateFile)) {
      const state = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
      state.lastHeartbeat = new Date().toISOString();
      fs.writeFileSync(stateFile, JSON.stringify(state, null, 2));
    }
  } catch (e) {
    // 忽略错误
  }
}

// ============================================================================
// Daemon
// ============================================================================

class Daemon {
  constructor() {
    this.logger = new Logger(CONFIG.logDir);
    this.stateStore = new StateStore(CONFIG.stateFile);
    this.componentManager = new ComponentManager(
      CONFIG.scriptsDir, 
      this.stateStore, 
      this.logger
    );
    this.scheduler = new Scheduler(
      this.componentManager, 
      this.stateStore, 
      this.logger
    );
    this.statusTimer = null;
    this.heartbeatTimer = null;
  }

  // PID 文件管理
  checkPid() {
    if (fs.existsSync(CONFIG.pidFile)) {
      const pid = parseInt(fs.readFileSync(CONFIG.pidFile, 'utf8'), 10);
      
      // 检查进程是否存在
      try {
        process.kill(pid, 0);
        console.error(`Daemon 已在运行 (PID: ${pid})`);
        process.exit(1);
      } catch (e) {
        // 进程不存在，删除旧 PID 文件
        fs.unlinkSync(CONFIG.pidFile);
      }
    }
    
    // 写入当前 PID
    fs.writeFileSync(CONFIG.pidFile, process.pid.toString());
    this.logger.info(`Daemon 启动 (PID: ${process.pid})`);
  }

  cleanupPid() {
    try {
      if (fs.existsSync(CONFIG.pidFile)) {
        const pid = parseInt(fs.readFileSync(CONFIG.pidFile, 'utf8'), 10);
        if (pid === process.pid) {
          fs.unlinkSync(CONFIG.pidFile);
        }
      }
    } catch (e) {
      // 忽略清理错误
    }
  }

  // 信号处理
  setupSignals() {
    const shutdown = (signal) => {
      this.logger.info(`收到 ${signal} 信号，正在关闭...`);
      this.stop();
      this.cleanupPid();
      process.exit(0);
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));
  }

  start() {
    this.checkPid();
    this.setupSignals();
    
    // 检查是否崩溃重启
    checkCrashRestart(this.logger);
    
    // 启动心跳更新
    this.heartbeatTimer = setInterval(() => {
      updateHeartbeat();
    }, CONFIG.heartbeatIntervalMs);

    // 注册所有任务
    for (const task of SCHEDULE) {
      this.scheduler.add(task.name, task.intervalMs, { dayOfWeek: task.dayOfWeek });
    }

    // 启动调度器
    this.scheduler.start();

    // 定期打印状态
    this.statusTimer = setInterval(() => {
      this.printStatus();
    }, CONFIG.statusIntervalMs);

    // 首次打印状态
    this.printStatus();

    this.logger.info('Daemon 运行中...');
  }

  stop() {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
    }
    if (this.statusTimer) {
      clearInterval(this.statusTimer);
    }
    this.scheduler.stop();
    
    // 更新状态为停止
    const stateFile = CONFIG.crashStateFile;
    try {
      if (fs.existsSync(stateFile)) {
        const state = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
        state.status = 'stopped';
        state.stopTime = new Date().toISOString();
        fs.writeFileSync(stateFile, JSON.stringify(state, null, 2));
      }
    } catch (e) {
      // 忽略错误
    }
  }

  printStatus() {
    this.logger.info('=== Daemon 状态 ===');
    for (const [name, task] of this.scheduler.tasks) {
      const state = this.stateStore.getTaskState(name);
      const nextRun = this.scheduler.nextRun(name);
      const nextRunStr = nextRun ? new Date(nextRun).toISOString() : 'N/A';
      const lastRunStr = state.lastRun ? new Date(state.lastRun).toISOString() : '从未运行';
      
      this.logger.info(
        `  ${name}: 状态=${state.status}, 运行次数=${state.runs}, ` +
        `上次=${lastRunStr}, 下次=${nextRunStr}`
      );
    }
    this.logger.info('==================');
  }

  async runOnce() {
    this.logger.info('执行所有组件一次...');
    
    for (const task of SCHEDULE) {
      await this.componentManager.run(task.name);
    }
    
    this.logger.info('所有组件执行完成');
  }

  printStatusOnce() {
    console.log('\n=== Daemon 当前状态 ===\n');
    
    if (!fs.existsSync(CONFIG.stateFile)) {
      console.log('无状态文件');
      return;
    }
    
    const state = JSON.parse(fs.readFileSync(CONFIG.stateFile, 'utf8'));
    console.log(`启动时间: ${new Date(state.startTime).toISOString()}`);
    console.log('\n任务状态:');
    
    for (const task of SCHEDULE) {
      const taskState = state.tasks[task.name] || { status: 'never', runs: 0 };
      const lastRun = taskState.lastRun ? new Date(taskState.lastRun).toISOString() : '从未运行';
      console.log(`\n  ${task.name}:`);
      console.log(`    状态: ${taskState.status}`);
      console.log(`    运行次数: ${taskState.runs}`);
      console.log(`    上次运行: ${lastRun}`);
      if (taskState.error) {
        console.log(`    错误: ${taskState.error}`);
      }
    }
    
    console.log('\n======================\n');
  }
}

// ============================================================================
// HTTP Status Server
// ============================================================================

function startHttpServer(daemon, port = 3001) {
  const http = require('http');
  
  const server = http.createServer((req, res) => {
    if (req.url === '/status' && req.method === 'GET') {
      // 返回 JSON 状态
      const state = daemon.stateStore.state;
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        uptime: process.uptime(),
        status: 'running',
        tasks: state.tasks,
        startTime: state.startTime,
        pid: process.pid
      }, null, 2));
    } else if (req.url === '/health' && req.method === 'GET') {
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end('OK');
    } else {
      res.writeHead(404);
      res.end('Not Found');
    }
  });
  
  server.listen(port, '127.0.0.1', () => {
    daemon.logger.info(`💻 HTTP 状态面板: http://localhost:${port}/status`);
  });
  
  server.on('error', (e) => {
    if (e.code === 'EADDRINUSE') {
      daemon.logger.warn(`⚠️ 端口 ${port} 已被占用，跳过 HTTP 服务器`);
    } else {
      daemon.logger.error(`HTTP 服务器错误: ${e.message}`);
    }
  });
  
  return server;
}

// ============================================================================
// CLI
// ============================================================================

async function main() {
  const args = process.argv.slice(2);
  const daemon = new Daemon();

  if (args.includes('--once')) {
    // 运行所有组件一次然后退出
    await daemon.runOnce();
    process.exit(0);
  }

  if (args.includes('--status')) {
    // 打印当前状态
    daemon.printStatusOnce();
    process.exit(0);
  }

  if (args.includes('--help') || args.includes('-h')) {
    console.log(`
Self-Evolving Agent Daemon

用法:
  node self-evolving-daemon.js         启动 daemon（后台运行）
  node self-evolving-daemon.js --once   执行所有组件一次后退出
  node self-evolving-daemon.js --status 打印当前状态
  node self-evolving-daemon.js --help   显示帮助

HTTP 状态面板:
  curl http://localhost:3001/status   查看 JSON 状态
  curl http://localhost:3001/health   健康检查

系统服务:
  systemctl start self-evolving-daemon   启动服务
  systemctl status self-evolving-daemon  查看状态
  systemctl stop self-evolving-daemon    停止服务
`);
    process.exit(0);
  }

  // 启动 HTTP 状态面板
  startHttpServer(daemon);

  // 正常启动 daemon
  daemon.start();
}

// 错误处理
process.on('uncaughtException', (e) => {
  console.error('Uncaught exception:', e);
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  console.error('Unhandled rejection:', reason);
});

main().catch((e) => {
  console.error('Fatal error:', e);
  process.exit(1);
});
