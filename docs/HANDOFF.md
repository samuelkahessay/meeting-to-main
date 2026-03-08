# Agent Handoff — meeting-to-main

## Pause Checkpoint — 2026-03-08

**Current status:** work is intentionally paused. The latest fresh smoke proved bootstrap still works with the local template snapshot, but the lane is currently blocked by GitHub Copilot quota before decomposition can complete.

### Latest smoke result

- **Repo:** `samuelkahessay/pipeline-smoke-canary-smoke-20260308151418`
- **Bootstrap:** succeeded
  - repo created from the local `prd-to-prod-template` snapshot
  - branch protection, secrets, variables, and lock-file compile all completed
  - root PRD issue `#1` was created and `/decompose` was triggered
- **Failure point:** `PRD Decomposer` failed in the Copilot agent step before creating child issues
- **Concrete blocker:** agent runtime returned `402 You have no quota`
- **Implication:** the current stop condition is external quota, not a newly proven workflow-routing regression

### Repo state at pause

- **`meeting-to-main`**
  - `origin/main` already includes `ac253b5` (`fix: harden smoke bootstrap flow`)
  - working tree is clean
  - branch is **ahead of `origin/main` by 1 local commit**: `3372fb6` `docs: capture pause checkpoint`
  - that local commit includes the `trigger/push-to-pipeline.sh` fallback change that moves the default `PIPELINE_APP_PRIVATE_KEY_FILE` path from the TCC-blocked `~/Downloads/...pem` path to the readable config path: `$HOME/.config/prd-to-prod/prd-to-prod-pipeline.2026-03-02.private-key.pem`
- **`prd-to-prod-template`**
  - working tree is clean
  - branch is **ahead of `origin/main` by 4 local commits**
  - unpushed commits:
    - `8426070` `fix: target child issue activation and dispatch`
    - `eb27f56` `chore: upgrade gh-aw lockfiles to v0.56.0`
    - `f6a322d` `chore: refresh agentics maintenance workflow`
    - `d3cb5cb` `test: add studio e2e coverage`

### Closed loops

- The App private key was moved out of `~/Downloads` and the stale `Downloads` copy was removed.
- Canonical readable key path is now `/Users/skahessay/.config/prd-to-prod/prd-to-prod-pipeline.2026-03-02.private-key.pem`.
- No local smoke command is still running.
- No PR was opened in the latest smoke repo, so there is no partially verified review/merge lane to clean up.

### Open loops left intentionally documented

- The latest smoke repo still exists for evidence: `samuelkahessay/pipeline-smoke-canary-smoke-20260308151418`
- Issue `#2` in that repo is the generated failure issue: `[aw] PRD Decomposer failed (pre-agent)`
- The 4 template commits are local only and have **not** been pushed
- The latest `meeting-to-main` handoff/key-path commit has **not** been pushed

### Exact next step when resuming

1. Restore Copilot quota or switch to credentials with quota.
2. Decide whether to push the local `meeting-to-main` handoff/key-path commit `3372fb6`.
3. Decide whether to push the 4 local `prd-to-prod-template` commits before further smoke runs.
4. Rerun one fresh smoke using:

```bash
PIPELINE_TEMPLATE_SOURCE_DIR=/Users/skahessay/Documents/Projects/active/prd-to-prod-template \
PIPELINE_SMOKE_TIMEOUT_SECONDS=1800 \
/Users/skahessay/Documents/Projects/active/meeting-to-main/trigger/smoke-pipeline.sh
```

5. If the quota issue is resolved and the run advances past decomposition, continue validating:
   - child issue creation
   - child `pipeline` activation
   - first PR creation
   - verdict comment
   - formal review
   - auto-merge

**Date:** 2026-03-08
**Status:** PRD extraction, repo bootstrap, and live deploy are verified; the March 7, 2026 autonomous merge lane was not fully hands-off. This repo now contains the v1 autonomy hardening changes and smoke-run tooling.
**Last local commit:** `3372fb6` (`docs: capture pause checkpoint`)
**Last pushed commit on `main`:** `ac253b5` (`fix: harden smoke bootstrap flow`)

---

## What this project does

One command (`./extraction/extract-prd.sh`) takes a meeting transcript, extracts a PRD via Claude, creates a fresh GitHub repo from a template, provisions all secrets and variables (pipeline + Vercel), files the PRD as an issue, and triggers the implementation lane. The live March 7, 2026 run proved extraction/bootstrap/deploy, but later PRs still required manual merges because the template repo's auth and review-submit chain were not yet fully App-backed.

**Live proof:** https://team-availability-service.vercel.app

## What was accomplished

1. **Live extraction and bootstrap** — real WorkIQ transcript → Claude PRD → fresh repo → issue creation → `/decompose`
2. **Live deploy proof** — the generated to-do/weather app reached Vercel and served working API routes
3. **Hardening implemented locally** — `push-to-pipeline.sh` now fails fast on missing App/deploy config, sets `PIPELINE_BOT_LOGIN`, validates Actions permissions, verifies compiled lock files, and exposes machine-readable outputs for smoke validation
4. **Smoke-run tooling added** — [`smoke-pipeline.sh`](/Users/skahessay/Documents/Projects/active/meeting-to-main/trigger/smoke-pipeline.sh) plus [`smoke-prd.md`](/Users/skahessay/Documents/Projects/active/meeting-to-main/trigger/smoke-prd.md) verify first-PR authoring, verdict comment creation, and formal review submission
5. **Template hardening staged locally** — the template workflows now use App-backed safe outputs, configurable reviewer trust via `PIPELINE_BOT_LOGIN`, and fail-closed dispatch/merge paths

## What still needs attention

### Verified live-run blockers
- **Later PRs were manually merged** — PRs `#9`, `#10`, `#12`, `#14`, and `#16` in `samuelkahessay/to-do-app-with-weather-and-notification-preferences` were merged by `samuelkahessay`, not by the autonomous merge lane.
- **Decomposer partial success bug** — the missing frontend issue was caused by invalid `temporary_id: aw_ui`, not by issue-number race conditions. The workflow still reported success and dispatched `repo-assist`.
- **GitHub App installation is still a real dependency** — if the App is not installed on the generated repo, autonomy still degrades even with the workflow fixes.
- **`docs/run-notes.md` is missing** — older references to that file are stale; the usable records in this repo are [`docs/HANDOFF.md`](/Users/skahessay/Documents/Projects/active/meeting-to-main/docs/HANDOFF.md) and [`docs/run-log-2026-03-07-live.md`](/Users/skahessay/Documents/Projects/active/meeting-to-main/docs/run-log-2026-03-07-live.md).

### v2 Vision
- Not every meeting = new PRD. Existing products will already have repos.
- WorkIQ will surface: new features, bugs, enhancements — not just greenfield PRDs.
- Pipeline needs to route to existing repos: open feature issues, file bugs, etc.
- Current pipeline = v1 (greenfield PRD → new repo). v2 = incremental work on existing repos.

## Key files

| File | Purpose |
|------|---------|
| `extraction/extract-prd.sh` | Entry point — chains all three layers |
| `extraction/prompt.md` | LLM prompt with platform constraints + deployment section |
| `extraction/validate.sh` | Structural + tech stack validation |
| `extraction/workiq-client.ts` | Live WorkIQ MCP client (opt-in via `WORKIQ_LIVE=true`) |
| `trigger/push-to-pipeline.sh` | Creates repo, provisions secrets/labels/agents/Vercel, files issue |
| `mocks/workiq-response.txt` | Prose meeting summary (mock input) |
| `mocks/transcript.json` | 31-turn meeting transcript (reference only) |

## Environment prerequisites

```bash
# Required in ~/.env
OPENROUTER_API_KEY=sk-or-...
COPILOT_GITHUB_TOKEN=github_pat_...  # fine-grained, Copilot permission under Account tab
VERCEL_TOKEN=...                     # from vercel.com/account/tokens
VERCEL_ORG_ID=cpIqySJjMorFLAHdSOUiu8RC

# Required CLI tools
gh       # authenticated with delete_repo scope
gh aw    # gh-aw extension for compiling agent workflows
npx tsx  # for workiq-client.ts

# Required for live WorkIQ (optional)
npx -y @microsoft/workiq  # authenticated for M365 tenant
```

## Traps for the next agent

1. **Fine-grained PAT, not classic.** gh-aw rejects `ghp_` tokens. Must be `github_pat_` with Copilot permission enabled under the **Account** tab (not Repository).
2. **Two-label dispatch.** Auto-dispatch requires `pipeline` + one of `bug`/`docs`/`feature`/`infra`/`test`. Missing the type label → silent no-op.
3. **`gh aw compile` needs two passes.** `prd-decomposer.md` depends on `repo-assist.lock.yml` existing. First pass compiles everything except prd-decomposer. Second pass picks it up.
4. **GitHub App installation.** Currently set to "selected repos". New repos aren't covered until manually added unless the installation scope changes.
5. **Vercel deploy needs `vercel link --yes`** — do NOT pass `VERCEL_ORG_ID` as env var without `VERCEL_PROJECT_ID`. Use `vercel link` to auto-create projects instead.
6. **Bash `${//}` expansion corrupts `$` and `\`** — use Python for prompt substitution.
7. **Tech stack guard** — the validator rejects PRDs with blocked stacks (C#, .NET, Java, etc.). If a meeting discusses unsupported tech, the prompt maps it to the closest allowed equivalent.
8. **Review-submit trust is bot-based now.** Generated repos need `PIPELINE_BOT_LOGIN` set to the GitHub App bot login, or verdict comments will be ignored.
