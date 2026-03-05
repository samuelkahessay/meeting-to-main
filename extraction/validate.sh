#!/usr/bin/env bash
# validate.sh — Structural validation for generated PRDs
# Sourced by extract-prd.sh; provides validate_prd() function

validate_prd() {
  local prd="$1"
  local errors=0

  if [ ! -f "$prd" ]; then
    echo "FAIL: PRD file not found: $prd"
    return 1
  fi

  grep -q "^# PRD:" "$prd"                || { echo "FAIL: Missing PRD title (expected '# PRD: ...')"; ((errors++)); }
  grep -q "^## Tech Stack" "$prd"          || { echo "FAIL: Missing Tech Stack section"; ((errors++)); }
  grep -q "^## Features" "$prd"            || { echo "FAIL: Missing Features section"; ((errors++)); }
  grep -q "^### Feature 1:" "$prd"         || { echo "FAIL: Missing Feature 1"; ((errors++)); }
  grep -q "^\- \[ \]" "$prd"              || { echo "FAIL: No acceptance criteria checkboxes found"; ((errors++)); }
  grep -q "^## Validation Commands" "$prd" || { echo "FAIL: Missing Validation Commands section"; ((errors++)); }
  grep -q "^## Non-Functional" "$prd"      || { echo "FAIL: Missing Non-Functional Requirements section"; ((errors++)); }
  grep -q "^## Out of Scope" "$prd"        || { echo "FAIL: Missing Out of Scope section"; ((errors++)); }

  if [ "$errors" -gt 0 ]; then
    echo ""
    echo "PRD validation failed with $errors error(s)"
    return 1
  fi

  return 0
}
