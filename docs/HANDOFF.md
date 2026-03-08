# Agent Handoff — meeting-to-main

**Date:** 2026-03-08
**Status:** PRD extraction, repo bootstrap, and live deploy are verified; the March 7, 2026 autonomous merge lane was not fully hands-off. This repo now contains the v1 autonomy hardening changes and smoke-run tooling.
**Last commit:** `0df7930` on `main` before the current hardening pass

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
