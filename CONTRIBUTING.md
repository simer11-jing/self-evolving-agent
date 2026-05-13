# Contributing to Self-Evolving Agent

Thanks for your interest! Here's how to help.

## Development Setup
```bash
git clone git@github.com:simer11-jing/self-evolving-agent.git
cd self-evolving-agent
python -m pip install -r requirements.txt
```

## Running Tests
```bash
bash tests/smoke.sh
```

## Pull Request Checklist
- [ ] All scripts pass syntax validation
- [ ] `tests/smoke.sh` passes
- [ ] No logs or temp files committed
- [ ] README updated if needed

## Code Style
- Shell: POSIX-compatible, `set -euo pipefail`
- Python: PEP 8
- JavaScript: Standard style
