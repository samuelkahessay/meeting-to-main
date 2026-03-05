#!/usr/bin/env bash
set -euo pipefail

PRD_FILE="${1:?Usage: push-to-pipeline.sh <prd-file>}"
REPO="${PIPELINE_REPO:-skahessay/prd-to-prod}"

if [ ! -f "$PRD_FILE" ]; then
  echo "[meeting-to-main] ERROR: PRD file not found: $PRD_FILE"
  exit 1
fi

# Extract title from PRD
PRD_TITLE=$(head -1 "$PRD_FILE" | sed 's/^# PRD: //')

# Read PRD content
PRD_BODY=$(cat "$PRD_FILE")

echo "[meeting-to-main] Creating issue in $REPO..."

# Create issue with PRD as body
ISSUE_URL=$(gh issue create \
  --repo "$REPO" \
  --title "[Pipeline] $PRD_TITLE" \
  --body "$PRD_BODY" \
  --label "pipeline")

ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')
echo "[meeting-to-main] Created issue #$ISSUE_NUMBER: $ISSUE_URL"

# Trigger decomposition
gh issue comment "$ISSUE_NUMBER" \
  --repo "$REPO" \
  --body "/decompose"

echo "[meeting-to-main] Triggered /decompose on issue #$ISSUE_NUMBER"
echo "[meeting-to-main] Pipeline will now: decompose -> implement -> PR -> merge"
