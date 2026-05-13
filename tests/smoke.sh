#!/usr/bin/env bash
set -euo pipefail

# Basic smoke checks
[ -f README.md ]
[ -f package.json ]
[ -f scripts/self-improving-controller.sh ]
[ -f scripts/optimization-engine.sh ]
[ -f scripts/openclaw-memory-infer.py ]

echo "smoke ok"
