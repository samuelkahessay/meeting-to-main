# Agent Handoff — meeting-to-main

**Date:** 2026-03-08
**Status:** E2E pipeline verified, deployed, and live on Vercel
**Last commit:** `0df7930` on `main`

---

## What this project does

One command (`./extraction/extract-prd.sh`) takes a meeting transcript, extracts a PRD via Claude, creates a fresh GitHub repo from a template, provisions all secrets (pipeline + Vercel), files the PRD as an issue, and triggers an autonomous pipeline that implements the entire project, opens a PR, merges it, and **auto-deploys to Vercel**.

**Live proof:** https://team-availability-service.vercel.app

## What was accomplished

1. **Full E2E pipeline** — mock transcript → Claude PRD (8 features) → `samuelkahessay/team-availability-service` created → 31 tests → PR #4 merged → live on Vercel
2. **Tech stack enforcement** — prompt constrains to Node.js/TS only; validator rejects C#, .NET, Java, Django, etc.
3. **Vercel auto-deploy** — template's `deploy-router.yml` supports `express-vercel` profile; `deploy-vercel.yml` uses `vercel link --yes` for auto project creation; `push-to-pipeline.sh` sets `VERCEL_TOKEN` on new repos
4. **PRD requires `api/index.ts`** — serverless entrypoint convention so every generated project is Vercel-deployable
5. **Live WorkIQ tested** — `sam@prdtoprod.onmicrosoft.com` authenticated, 1 real transcript available (March 6, short)
6. **Noisy workflows disabled** on team-availability-service (CI Failure Doctor/Router/Resolver, Studio CI, etc.)

## What still needs attention

### Must do for clean re-runs
- **GitHub App installation is "selected repos"** — each new repo must be manually added at `github.com/settings/installations` → `prd-to-prod-pipeline` → add repo. Switch to "All repositories" to eliminate this.
- **`COPILOT_GITHUB_TOKEN` expires June 5, 2026** — will need rotation before then.

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
4. **GitHub App installation.** Currently set to "selected repos". New repos aren't covered until manually added.
5. **Vercel deploy needs `vercel link --yes`** — do NOT pass `VERCEL_ORG_ID` as env var without `VERCEL_PROJECT_ID`. Use `vercel link` to auto-create projects instead.
6. **Bash `${//}` expansion corrupts `$` and `\`** — use Python for prompt substitution.
7. **Tech stack guard** — the validator rejects PRDs with blocked stacks (C#, .NET, Java, etc.). If a meeting discusses unsupported tech, the prompt maps it to the closest allowed equivalent.
