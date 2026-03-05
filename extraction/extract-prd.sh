#!/usr/bin/env bash
set -euo pipefail

# Resolve project root (parent of extraction/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== meeting-to-main ==="
echo ""

# Step 1: WorkIQ extraction (or mock)
# Use live WorkIQ by setting WORKIQ_LIVE=true:
#   WORKIQ_LIVE=true ./extraction/extract-prd.sh "my meeting query"
echo "[1/3] Fetching meeting data via WorkIQ..."
if [ "${WORKIQ_LIVE:-}" = "true" ]; then
  WORKIQ_OUTPUT=$(npx tsx "$PROJECT_ROOT/extraction/workiq-client.ts" "${1:-Product Sync}")
  echo "      Using live WorkIQ MCP"
else
  WORKIQ_OUTPUT=$(cat "$PROJECT_ROOT/mocks/workiq-response.txt")
  echo "      Using mock WorkIQ data"
fi

# Step 2: PRD extraction via LLM
echo "[2/3] Extracting PRD from meeting transcript..."
PROMPT=$(cat "$PROJECT_ROOT/extraction/prompt.md")
PROMPT="${PROMPT//\{workiq_output\}/$WORKIQ_OUTPUT}"
claude --print "$PROMPT" > "$PROJECT_ROOT/generated-prd.md"
echo "      PRD written to generated-prd.md"

# Validate
source "$PROJECT_ROOT/extraction/validate.sh"
if ! validate_prd "$PROJECT_ROOT/generated-prd.md"; then
  echo ""
  echo "ERROR: Generated PRD failed validation. Check generated-prd.md and retry."
  exit 1
fi
echo "      PRD validation passed"

# Step 3: Trigger pipeline
echo "[3/3] Pushing PRD to prd-to-prod pipeline..."
bash "$PROJECT_ROOT/trigger/push-to-pipeline.sh" "$PROJECT_ROOT/generated-prd.md"

echo ""
echo "=== Done. Watch prd-to-prod for pipeline activity. ==="
