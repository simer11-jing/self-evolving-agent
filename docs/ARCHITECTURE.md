# Architecture

## Overview

Self-Evolving Agent is a lightweight self-improvement system for AI agents. It focuses on:

- **Resource Monitoring**: CPU, memory, disk, and error log tracking
- **Error Analysis**: Pattern detection and reporting
- **Memory Integration**: Working with external memory systems
- **Safety First**: Sandbox validation before execution

## System Architecture

```
+-----------------+       +-----------------+
|   User Input    |       |  Resource Monitor |
+-----------------+       +---------+-------+
        |                           |
        v                           v
+-----------------+       +---------+-------+
|  Main Controller|------>|  Error Analyzer  |
+-----------------+       +---------+-------+
        |                           |
        v                           v
+-----------------+       +---------+-------+
|  Sandbox Validator          |  Backup System   |
+-----------------+       +---------+-------+
        |                           |
        v                           v
+-----------------+       +-----------------+
|  Optimization   |       |  Memory System   |
+-----------------+       +-----------------+
```

## Key Components

### 1. Main Controller (`self-improving-controller.sh`)
- Orchestrates all monitoring and optimization tasks
- Manages execution flow with safety checks
- Handles backup and rollback

### 2. Resource Monitor (`memory-monitor.js`)
- Cross-platform Python-based monitoring via `psutil-wrapper.py`
- Node.js interface for unified execution
- CSV output for structured data collection

### 3. Sandbox Validator (`sandbox-validator.sh`)
- AST static analysis for Python scripts
- Dangerous command detection for shell scripts
- Prevents execution of unsafe code

### 4. Backup System
- Automatic backup before any execution
- Timestamped backup directories
- Easy rollback capability

## Data Flow

1. **Monitor Phase**: Resource and error data is collected
2. **Validate Phase**: Code safety is verified
3. **Backup Phase**: Current state is preserved
4. **Execute Phase**: Optimization is performed
5. **Report Phase**: Results are logged and archived

## Security Model

- **Defense in Depth**: Multiple validation layers
- **Principle of Least Privilege**: Minimal permissions required
- **Fail-Safe Defaults**: Blocked by default, explicitly allowed
- **Audit Trail**: All actions logged with timestamps

## Extension Points

- Add new monitors by extending `lib/monitor.js`
- Add new analyzers by extending `lib/error-analyzer.mjs`
- Configure thresholds in `config/thresholds.json`
