#!/usr/bin/env bash
set -euo pipefail

PRD_FILE="${1:?Usage: push-to-pipeline.sh <prd-file>}"
TEMPLATE_REPO="${PIPELINE_TEMPLATE:-samuelkahessay/prd-to-prod-template}"
GH_OWNER="${PIPELINE_OWNER:-samuelkahessay}"
PIPELINE_APP_ID="${PIPELINE_APP_ID:-2995372}"

if [ ! -f "$PRD_FILE" ]; then
  echo "[meeting-to-main] ERROR: PRD file not found: $PRD_FILE"
  exit 1
fi

# Extract title from PRD and derive repo name
PRD_TITLE=$(head -1 "$PRD_FILE" | sed 's/^# PRD: //')
REPO_NAME=$(printf '%s' "$PRD_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
REPO="$GH_OWNER/$REPO_NAME"

# Create a new repo from the pipeline template
echo "[meeting-to-main] Creating repo $REPO from template $TEMPLATE_REPO..."
gh repo create "$REPO" \
  --template "$TEMPLATE_REPO" \
  --public \
  --clone=false

# Wait for GitHub to finish creating the repo from template
echo "[meeting-to-main] Waiting for repo to be ready..."
for i in $(seq 1 10); do
  if gh repo view "$REPO" &>/dev/null; then
    break
  fi
  sleep 2
done

# Ensure required labels exist (GitHub doesn't copy labels from templates)
gh label create "pipeline" --repo "$REPO" --description "Pipeline-managed issue" --color "0075ca" 2>/dev/null || true
gh label create "feature" --repo "$REPO" --description "New feature" --color "a2eeef" 2>/dev/null || true

# Copy pipeline secrets/variables (GitHub doesn't copy these from templates either)
echo "[meeting-to-main] Configuring pipeline secrets on $REPO..."
gh variable set PIPELINE_APP_ID --repo "$REPO" --body "$PIPELINE_APP_ID"
if [ -n "${PIPELINE_APP_PRIVATE_KEY:-}" ]; then
  gh secret set PIPELINE_APP_PRIVATE_KEY --repo "$REPO" --body "$PIPELINE_APP_PRIVATE_KEY"
elif [ -f "${PIPELINE_APP_PRIVATE_KEY_FILE:-$HOME/Downloads/prd-to-prod-pipeline.2026-03-02.private-key.pem}" ]; then
  gh secret set PIPELINE_APP_PRIVATE_KEY --repo "$REPO" < "${PIPELINE_APP_PRIVATE_KEY_FILE:-$HOME/Downloads/prd-to-prod-pipeline.2026-03-02.private-key.pem}"
else
  echo "[meeting-to-main] WARNING: PIPELINE_APP_PRIVATE_KEY not set — auto-dispatch will fail"
  echo "         Set it via: export PIPELINE_APP_PRIVATE_KEY=\$(cat /path/to/private-key.pem)"
fi
if [ -n "${COPILOT_GITHUB_TOKEN:-}" ]; then
  gh secret set COPILOT_GITHUB_TOKEN --repo "$REPO" --body "$COPILOT_GITHUB_TOKEN"
else
  echo "[meeting-to-main] WARNING: COPILOT_GITHUB_TOKEN not set — repo-assist agents will fail"
fi

# Compile gh-aw agent workflows (templates don't include .lock.yml files)
echo "[meeting-to-main] Compiling agent workflows..."
CLONE_DIR=$(mktemp -d)
gh repo clone "$REPO" "$CLONE_DIR" -- --quiet 2>/dev/null
(cd "$CLONE_DIR" && gh aw compile 2>/dev/null; gh aw compile 2>/dev/null || true)
if ls "$CLONE_DIR"/.github/workflows/*.lock.yml &>/dev/null; then
  (cd "$CLONE_DIR" && git add -A && git commit -m "chore: compile gh-aw agent lock files" --quiet && git push origin main --quiet)
  echo "      Agent workflows compiled and pushed"
else
  echo "      WARNING: No agent lock files generated — repo-assist may not dispatch"
fi
rm -rf "$CLONE_DIR"

# Create issue with PRD as body (--body-file avoids shell quoting issues with backticks/markdown)
echo "[meeting-to-main] Creating PRD issue in $REPO..."
ISSUE_URL=$(gh issue create \
  --repo "$REPO" \
  --title "[Pipeline] $PRD_TITLE" \
  --body-file "$PRD_FILE" \
  --label "pipeline" \
  --label "feature")

ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')
echo "[meeting-to-main] Created issue #$ISSUE_NUMBER: $ISSUE_URL"

# Trigger decomposition
gh issue comment "$ISSUE_NUMBER" \
  --repo "$REPO" \
  --body "/decompose"

echo "[meeting-to-main] Triggered /decompose on issue #$ISSUE_NUMBER"
echo "[meeting-to-main] Pipeline repo: https://github.com/$REPO"
echo "[meeting-to-main] Pipeline will now: decompose -> implement -> PR -> merge"
