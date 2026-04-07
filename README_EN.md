# Self-Evolving Agent

_An automated self-improvement system that gives your AI assistant the ability to evolve_

---

## 📋 Overview

**Self-Evolving Agent** is an automated self-improvement system that enables AI assistants to:

- 🔍 **Continuous Monitoring** - Monitor system performance and resource usage
- 🐛 **Auto-Correction** - Analyze error patterns and provide fixes
- ⚡ **Smart Optimization** - Automatically optimize based on triggers
- 📚 **Skill Learning** - Analyze gaps and automatically learn new skills
- 🔄 **Feedback Loop** - Collect and process user feedback
- 🧠 **Periodic Reflection** - Reflect based on Hindsight architecture

---

## 🎯 Core Features

### 1. Performance Monitoring

Automatically monitors system performance:

| Metric | Description |
|--------|-------------|
| CPU Usage | System CPU usage percentage |
| Memory Usage | System memory usage percentage |
| Disk Usage | Disk space usage percentage |
| Active Sessions | OpenClaw active session count |
| Gateway Status | OpenClaw gateway running status |

**Trigger Thresholds**:
- CPU > 80% → Trigger optimization
- Memory > 80% → Trigger optimization
- Disk > 90% → Trigger optimization

### 2. Error Analysis

Automatically analyzes and logs errors:

- Analyze OpenClaw error logs
- Check Cron task failures
- Identify error patterns
- Provide fix suggestions

### 3. Optimization Engine

Automatically optimizes based on detected issues:

| Trigger | Optimization |
|---------|--------------|
| `high_resource_usage` | Clean temp files, cache, logs |
| `memory_leak` | Restart leaking processes |
| `disk_full` | Clean large logs and old backups |

### 4. Skill Learning

Automatically analyzes user needs and learns new skills:

```
User Need → Pattern Recognition → Skill Gap Detection → Auto Install
```

**Supported Auto-Learn Skills**:
- 🌤️ Weather queries
- 📧 Email processing
- 📊 Stock analysis
- 🔍 Web search
- 📁 File management

### 5. Feedback Loop

Collects and processes user feedback:

- Analyze feedback types (positive/improvement)
- Identify feedback patterns
- Continuously improve service quality

### 6. Weekly Reflection

Periodic reflection based on Hindsight architecture:

- Review memories from the past week/month
- Identify success patterns and areas for improvement
- Update long-term memory

---

## 🚀 Quick Start

### Installation

```bash
# Method 1: Using alphaclaw (recommended)
alphaclaw install self-evolving-agent

# Method 2: Manual installation
git clone https://github.com/simer11-jing/self-evolving-agent.git ~/.openclaw/skills/self-evolving-agent
```

### Configure Cron Job

```bash
# Edit crontab
crontab -e

# Add cron job (runs daily at 23:00)
0 23 * * * /path/to/self-evolving-agent/scripts/self-improving-controller.sh
```

### Manual Run

```bash
# Run full workflow
./self-improving-controller.sh

# Run performance monitoring only
./self-improving-controller.sh --monitor

# Run optimization engine only
./self-improving-controller.sh --optimize

# Generate report only
./self-improving-controller.sh --report
```

---

## 📁 Directory Structure

```
self-evolving-agent/
├── SKILL.md                    # This file
├── README.md                   # Chinese documentation
├── README_EN.md               # English documentation
├── LICENSE                    # MIT License
├── package.json               # NPM configuration
├── scripts/
│   ├── self-improving-controller.sh  # Main controller
│   ├── performance-monitor.sh        # Performance monitoring
│   ├── error-analyzer.sh             # Error analysis
│   ├── optimization-engine.sh         # Optimization engine
│   ├── skill-learner.sh              # Skill learning
│   ├── feedback-loop.sh              # Feedback loop
│   └── memory-reflect.sh             # Memory reflection
└── examples/
    └── USAGE.md                # Usage examples
```

---

## ⚙️ Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                   Self-Improving Controller                  │
│                    (runs daily at 23:00)                    │
└─────────────────────────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│ Performance │      │    Error    │      │    Skill    │
│  Monitor    │      │  Analyzer   │      │   Learner   │
│  5 min     │      │   3 min    │      │   5 min     │
└─────────────┘      └─────────────┘      └─────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│Check Thres-│      │Error Pattern│      │ Demand Gap  │
│  holds     │      │Report Gen   │      │ Auto Install│
└─────────────┘      └─────────────┘      └─────────────┘
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Generate Report │
                    │ Update Memory   │
                    │ WeChat Notice   │
                    └─────────────────┘
```

---

## 🔧 Relationship with Hindsight Memory

**Self-Evolving Agent** and **Hindsight Memory** are complementary systems:

| Dimension | Hindsight Memory | Self-Evolving Agent |
|-----------|------------------|---------------------|
| **Core Function** | Memory storage & retrieval | System performance optimization |
| **Focus** | Information & knowledge | Systems & processes |
| **Mode** | Passive recording | Active optimization |
| **Analogy** | 📚 Library | 🔧 Repair shop |

**Collaboration Flow**:
```
Self-Evolving Agent → Analyze Memory → Find Optimization → Execute → Update Memory
                                              ↓
                                    Hindsight Memory
```

---

## 📊 Comparison with Similar Skills

| Feature | YMIR777 / pskoett | **Self-Evolving Agent** |
|---------|-------------------|-------------------------|
| **Trigger** | Manual (on request) | ✅ **Auto Scheduled** |
| **Monitoring** | Learnings & errors only | ✅ **Performance+Errors+Optimization+Skills** |
| **Optimization** | None | ✅ **Auto Optimization Engine** |
| **Reporting** | None | ✅ **Detailed Reports** |
| **Notifications** | None | ✅ **WeChat Push** |
| **Skill Learning** | None | ✅ **Auto Analyze+Install** |
| **Closed-Loop** | None | ✅ **Detect→Analyze→Optimize→Verify** |

---

## 🎯 Use Cases

- ✅ Want AI assistant to automatically optimize performance
- ✅ Need to automatically monitor system resources
- ✅ Want AI to automatically learn new skills
- ✅ Need periodic improvement reports
- ✅ Want AI to have self-improvement ability

---

## ⚠️ Notes

1. **Permissions**: Needs write access to `~/.openclaw/workspace`
2. **Dependencies**: Requires `jq`, `curl`, `top`, `free`, `df` and other system tools
3. **Cron Job**: Recommended to run late at night to avoid affecting normal operations
4. **Cleanup**: Logs kept for 30 days by default, reports kept for 180 days

---

## 🤝 Contributing

Issues and Pull Requests are welcome!

---

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details

---

## 🙏 Acknowledgments

- Based on [Hindsight Memory System](https://github.com/simer11-jing/hindsight-memory) architecture
- Inspired by [openclaw/skills](https://github.com/openclaw/skills) design
- Uses [alphaclaw](https://clawhub.ai) for package management

---

_Let your AI assistant evolve and become a better version of itself!_ 🚀