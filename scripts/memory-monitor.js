#!/usr/bin/env node

/**
 * P0_M01：memory-monitor.js
 * 集成资源监控、错误分析、CSV 记录
 */

import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function safeExecSync(cmd: string, defaultValue = null) {
  try {
    return execSync(cmd, { encoding: 'utf8', timeout: 5000 }).trim();
  } catch {
    return defaultValue;
  }
}

/** 资源监控 */async function performanceMonitor() {
  const cpu = safeExecSync('python3 "' + path.join(__dirname, 'psutil-wrapper.py') + '"') ?? '{"cpu": 0, "mem": 0, "disk": 0}';
  return JSON.parse(cpu);
}

/** 错误分析 */async function errorAnalyzer() {
  const logs = safeExecSync('grep -r "ERROR\\|error\\|CRITICAL" /var/log/opclaw/ 2>/dev/null || true');
  return logs.split('\n').filter(Boolean).length;
}

/**　CSV Writer  */async function writeErrorCSV(errors: number, outDir = path.join(__dirname, '../backup/errors')) {
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  const ts = new Date().toISOString().slice(0,19).replace(/[:T]/g, '-');
  const csv = `${outDir}/error-${ts}.csv\ncount,${errors}\n`;
  fs.writeFileSync(path.join(outDir, `error-${ts}.csv`), csv);
}

/** Entry */
async function main() {
  const mode = process.argv[2] || 'full';
  let metrics, errors;
  if (mode === 'health') {
    metrics = await performanceMonitor();
    console.table({ metrics });
    return;
  }
  metrics = await performanceMonitor();
  errors = await errorAnalyzer();
  await writeErrorCSV(errors);
  console.table({ metrics, errors });
}

await main();
