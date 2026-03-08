#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE_PRD_FILE="${1:-$PROJECT_ROOT/trigger/smoke-prd.md}"
PIPELINE_BOT_LOGIN="${PIPELINE_BOT_LOGIN:-prd-to-prod-pipeline}"
SMOKE_TIMEOUT_SECONDS="${PIPELINE_SMOKE_TIMEOUT_SECONDS:-1800}"
PIPELINE_REPO_SUFFIX="${PIPELINE_REPO_SUFFIX:-smoke-$(date -u +%Y%m%d%H%M%S)}"
DELETE_REPO="${PIPELINE_DELETE_SMOKE_REPO:-false}"
START_ISO="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

log() {
  echo "[smoke-pipeline] $*"
}

fail() {
  echo "[smoke-pipeline] ERROR: $*" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Required command not found: $1"
  fi
}

deadline_from_now() {
  date -u -v+"${SMOKE_TIMEOUT_SECONDS}"S +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
    date -u -d "+${SMOKE_TIMEOUT_SECONDS} seconds" +"%Y-%m-%dT%H:%M:%SZ"
}

to_epoch() {
  date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null || \
    date -u -d "$1" +%s
}

wait_for_condition() {
  local description=$1
  local check_function=$2
  local deadline_epoch

  deadline_epoch=$(to_epoch "$(deadline_from_now)")
  while [ "$(date -u +%s)" -lt "$deadline_epoch" ]; do
    if "$check_function"; then
      return 0
    fi
    sleep 15
  done

  fail "Timed out waiting for: $description"
}

pipeline_bot_login_candidates() {
  local configured=$1
  local base=$configured

  if [[ "$base" == *"[bot]" ]]; then
    base="${base%\[bot\]}"
  fi

  printf '%s\n' "$configured" "$base" "app/$configured" "app/$base" | awk 'NF && !seen[$0]++'
}

login_matches_pipeline_bot() {
  local actual=$1
  local candidate

  while IFS= read -r candidate; do
    [ "$actual" = "$candidate" ] && return 0
  done < <(pipeline_bot_login_candidates "$PIPELINE_BOT_LOGIN")

  return 1
}

find_first_pipeline_pr() {
  PR_NUMBER=$(gh pr list --repo "$PIPELINE_REPO" --state open --search "[Pipeline] in:title" --limit 20 --json number,title,createdAt \
    --jq "[.[] | select(.createdAt >= \"$START_ISO\")] | sort_by(.createdAt) | first | .number // \"\"")
  [ -n "$PR_NUMBER" ]
}

find_review_agent_run() {
  gh run list --repo "$PIPELINE_REPO" --workflow pr-review-agent.lock.yml --limit 20 --json createdAt,status \
    --jq "[.[] | select(.createdAt >= \"$START_ISO\")] | length > 0" | grep -qx true
}

find_verdict_comment() {
  local comment_id
  local comment_login

  while IFS=$'\t' read -r comment_id comment_login; do
    if login_matches_pipeline_bot "$comment_login"; then
      VERDICT_COMMENT_ID=$comment_id
      return 0
    fi
  done < <(gh api "/repos/$PIPELINE_REPO/issues/$PR_NUMBER/comments?per_page=100" \
    --jq '.[] | select((.body // "" | startswith("[PIPELINE-VERDICT]"))) | [.id, .user.login] | @tsv')

  return 1
}

find_formal_review() {
  REVIEW_STATE=$(gh api "/repos/$PIPELINE_REPO/pulls/$PR_NUMBER/reviews" \
    --jq '[.[] | select(.user.login == "github-actions[bot]")] | last | .state // ""')
  [ -n "$REVIEW_STATE" ]
}

require_command gh
require_command git
require_command jq

[ -f "$SMOKE_PRD_FILE" ] || fail "Smoke PRD file not found: $SMOKE_PRD_FILE"

TEMPLATE_SOURCE_SNAPSHOT=""
cleanup() {
  if [ -n "$TEMPLATE_SOURCE_SNAPSHOT" ] && [ -d "$TEMPLATE_SOURCE_SNAPSHOT" ]; then
    rm -rf "$TEMPLATE_SOURCE_SNAPSHOT"
  fi
  if [ "$DELETE_REPO" = "true" ] && [ -n "${PIPELINE_REPO:-}" ]; then
    gh repo delete "$PIPELINE_REPO" --yes >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [ -n "${PIPELINE_TEMPLATE_SOURCE_DIR:-}" ]; then
  [ -d "$PIPELINE_TEMPLATE_SOURCE_DIR" ] || fail "PIPELINE_TEMPLATE_SOURCE_DIR does not exist: $PIPELINE_TEMPLATE_SOURCE_DIR"
  TEMPLATE_SOURCE_SNAPSHOT=$(mktemp -d)
  rsync -a --exclude .git "$PIPELINE_TEMPLATE_SOURCE_DIR"/ "$TEMPLATE_SOURCE_SNAPSHOT"/
  (
    cd "$TEMPLATE_SOURCE_SNAPSHOT"
    git init -b main >/dev/null
    git add -A
    git commit -m "smoke template snapshot" --quiet
  )
  export PIPELINE_TEMPLATE_SOURCE_DIR="$TEMPLATE_SOURCE_SNAPSHOT"
  log "Using local template snapshot from $PIPELINE_TEMPLATE_SOURCE_DIR"
fi

OUTPUT_FILE=$(mktemp)
PIPELINE_REPO_SUFFIX="$PIPELINE_REPO_SUFFIX" "$PROJECT_ROOT/trigger/push-to-pipeline.sh" "$SMOKE_PRD_FILE" | tee "$OUTPUT_FILE"

PIPELINE_REPO=$(sed -n 's/^PIPELINE_REPO=//p' "$OUTPUT_FILE" | tail -1)
PIPELINE_REPO_URL=$(sed -n 's/^PIPELINE_REPO_URL=//p' "$OUTPUT_FILE" | tail -1)
PIPELINE_ISSUE_NUMBER=$(sed -n 's/^PIPELINE_ISSUE_NUMBER=//p' "$OUTPUT_FILE" | tail -1)

[ -n "$PIPELINE_REPO" ] || fail "Could not parse PIPELINE_REPO from push-to-pipeline output"
[ -n "$PIPELINE_ISSUE_NUMBER" ] || fail "Could not parse PIPELINE_ISSUE_NUMBER from push-to-pipeline output"

log "Waiting for first pipeline PR in $PIPELINE_REPO..."
PR_NUMBER=""
wait_for_condition \
  "first pipeline PR" \
  find_first_pipeline_pr

PR_AUTHOR=$(gh pr view "$PR_NUMBER" --repo "$PIPELINE_REPO" --json author --jq '.author.login')
login_matches_pipeline_bot "$PR_AUTHOR" || fail "First PR author was '$PR_AUTHOR' instead of one of: $(paste -sd ', ' < <(pipeline_bot_login_candidates "$PIPELINE_BOT_LOGIN"))"

log "Waiting for pr-review-agent workflow run..."
wait_for_condition \
  "pr-review-agent workflow run" \
  find_review_agent_run

VERDICT_COMMENT_ID=""
log "Waiting for [PIPELINE-VERDICT] comment from $PIPELINE_BOT_LOGIN..."
wait_for_condition \
  "verdict comment" \
  find_verdict_comment

REVIEW_STATE=""
log "Waiting for pr-review-submit to convert the verdict into a formal review..."
wait_for_condition \
  "formal review submission" \
  find_formal_review

log "Smoke run passed"
log "Repo: $PIPELINE_REPO_URL"
log "Issue: #$PIPELINE_ISSUE_NUMBER"
log "PR: https://github.com/$PIPELINE_REPO/pull/$PR_NUMBER"
log "Review state: $REVIEW_STATE"
