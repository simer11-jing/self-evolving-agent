.PHONY: all smoke test validate clean help

all: validate smoke

smoke:
	@bash tests/smoke.sh

validate:
	@echo "Checking shell scripts..."
	@find scripts -type f -name "*.sh" -exec bash -n {} \;
	@echo "Checking Python syntax..."
	@find . -type f -name "*.py" -print0 | xargs -0 python -m py_compile
	@echo "Checking JavaScript syntax..."
	@find . -type f \( -name "*.js" -o -name "*.mjs" \) -not -path "./node_modules/*" -print0 | xargs -0 -I{} node --check {}
	@echo "All checks passed."

clean:
	@rm -rf __pycache__ *.pyc
	@find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name "node_modules" -exec rm -rf {} + 2>/dev/null || true
	@echo "Cleaned."

help:
	@echo "Available targets:"
	@echo "  all      - Run validation and smoke tests"
	@echo "  smoke    - Run smoke tests"
	@echo "  validate - Validate all scripts"
	@echo "  clean    - Clean cache and temp files"
