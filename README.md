# Self-Evolving Agent

A **self-improving automation layer** for AI agents, focusing on:
- **Resource monitoring**
- **Error analysis**
- **Memory integration**
- **Automated optimization**

## Features

✅ **Multi-layer monitoring**: CPU, memory, disk, and error logs
✅ **Python-based**: Cross-platform resource monitoring
✅ **CSV reporting**: Structured error logs for analysis
✅ **Sandbox validation**: Safe execution environment

## Usage

```bash
# Run full monitoring
node scripts/memory-monitor.js full

# Run health check
node scripts/memory-monitor.js health
```

## Architecture

```text
scripts/          # Main scripts
├── memory-monitor.js  # Resource + error monitoring
├── sandbox-validator.sh # Safe execution
├── optimize-engine.js # Strategy execution
lib/              # Core modules
├── psutil-wrapper.py  # Resource monitoring
├── error-analyzer.mjs # Error parsing
└── io.js           # CSV/JSON I/O
backup/           # Execution backups
```

## Contributing

See `CONTRIBUTING.md` for setup and testing guidelines.

## License

MIT