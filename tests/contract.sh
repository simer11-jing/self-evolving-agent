# Script Contract Tests

## memory-reflect.sh

```bash
# Test reflection output format
REFLECTION_OUTPUT=$(bash scripts/memory-reflect.sh 7 2>&1)

# Verify JSON structure
if ! echo "$REFLECTION_OUTPUT" | jq empty >/dev/null 2>&1; then
  echo "ERROR: memory-reflect.sh output is not valid JSON"
  exit 1
fi

# Verify required fields
REQUIRED_FIELDS=("date" "decisions" "errors" "improvements")
for field in "${REQUIRED_FIELDS[@]}"; do
  if ! echo "$REFLECTION_OUTPUT" | jq -e ".$field" >/dev/null 2>&1; then
    echo "ERROR: memory-reflect.sh output missing required field: $field"
    exit 1
  fi
done

# Verify shared memory file was created
if [ ! -f "$HOME/.openclaw/agents/shared/observations/reflection-$(date +%Y%m%d).json" ]; then
  echo "ERROR: memory-reflect.sh did not create shared memory file"
  exit 1
fi
```

## error-analyzer.sh

```bash
# Test error analysis output format
ERROR_OUTPUT=$(bash scripts/error-analyzer.sh 2>&1)

# Verify CSV structure
if ! echo "$ERROR_OUTPUT" | grep -q "timestamp,error_type,severity,message"; then
  echo "ERROR: error-analyzer.sh output does not have CSV header"
  exit 1
fi

# Verify at least one error record
if [ $(echo "$ERROR_OUTPUT" | wc -l) -lt 2 ]; then
  echo "ERROR: error-analyzer.sh did not produce any error records"
  exit 1
fi
```

## optimization-engine.sh

```bash
# Test optimization output format
OPTIMIZATION_OUTPUT=$(bash scripts/optimization-engine.sh 2>&1)

# Verify JSON structure
if ! echo "$OPTIMIZATION_OUTPUT" | jq empty >/dev/null 2>&1; then
  echo "ERROR: optimization-engine.sh output is not valid JSON"
  exit 1
fi

# Verify required fields
REQUIRED_FIELDS=("strategy" "actions" "expected_impact")
for field in "${REQUIRED_FIELDS[@]}"; do
  if ! echo "$OPTIMIZATION_OUTPUT" | jq -e ".$field" >/dev/null 2>&1; then
    echo "ERROR: optimization-engine.sh output missing required field: $field"
    exit 1
  fi
done
```

## sandbox-validator.sh

```bash
# Test sandbox validation
VALID_SCRIPT="#!/bin/bash\necho 'safe operation'"
INVALID_SCRIPT="#!/bin/bash\nrm -rf /"

# Test valid script passes
if ! bash scripts/sandbox-validator.sh analyze <(echo "$VALID_SCRIPT"); then
  echo "ERROR: sandbox-validator.sh incorrectly rejected valid script"
  exit 1
fi

# Test invalid script is rejected
if bash scripts/sandbox-validator.sh analyze <(echo "$INVALID_SCRIPT"); then
  echo "ERROR: sandbox-validator.sh did not reject dangerous script"
  exit 1
fi
```
