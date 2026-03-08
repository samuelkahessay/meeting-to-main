# meeting-to-main

Meeting transcript in. Deployed API out. The March 7, 2026 live run still needed manual recovery in the merge lane; this repo now includes the App-first hardening and smoke-run checks to remove that gap.

```bash
source ~/.env && ./extraction/extract-prd.sh
```

One command takes a Teams meeting transcript, extracts a structured PRD using Claude, spins up a fresh repo, validates the pipeline bootstrap, and triggers the implementation lane — then **auto-deploys to Vercel** once the template repo's autonomous auth chain is healthy.

**Live proof:** [team-availability-service.vercel.app](https://team-availability-service.vercel.app) and [to-do-app-with-weather-and-notifica.vercel.app](https://to-do-app-with-weather-and-notifica.vercel.app). The latter was produced from a real WorkIQ transcript, but several later PRs were manually merged during the March 7, 2026 run.

## How it works

```
Teams Meeting → WorkIQ MCP → Claude extracts PRD → New repo from template
    → /decompose → repo-assist builds it → PR merged → Vercel deploy
```

The pipeline has three layers, each a directory:

- **`mocks/`** — A realistic 31-turn meeting transcript and WorkIQ prose summary. Swap for live WorkIQ data with `WORKIQ_LIVE=true`.
- **`extraction/`** — Claude (via OpenRouter) transforms the meeting summary into a validated PRD. Structural checks and tech stack guards catch issues before anything ships.
- **`trigger/`** — Creates a fresh repo from [`prd-to-prod-template`](https://github.com/samuelkahessay/prd-to-prod-template) or a local template snapshot, provisions secrets/variables (pipeline + Vercel), validates bootstrap state, files the PRD as a `[Pipeline]` issue, comments `/decompose`, and exposes a disposable smoke-run path.

## Running it

The default path uses mock data — no M365 tenant needed:

```bash
# Prerequisites: OPENROUTER_API_KEY, COPILOT_GITHUB_TOKEN, VERCEL_TOKEN,
# VERCEL_ORG_ID, PIPELINE_APP_PRIVATE_KEY in ~/.env
# gh CLI authenticated
source ~/.env
./extraction/extract-prd.sh
```

For live Teams data via [WorkIQ](https://github.com/microsoft/workiq) MCP:

```bash
source ~/.env
WORKIQ_LIVE=true ./extraction/extract-prd.sh "Product Sync March 3rd"
```

For a disposable autonomy smoke run against a template snapshot:

```bash
source ~/.env
PIPELINE_TEMPLATE_SOURCE_DIR=/path/to/prd-to-prod-template ./trigger/smoke-pipeline.sh
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `WORKIQ_LIVE` | `false` | Set `true` to use live M365 meeting data |
| `DEPLOY_PLATFORM` | `Vercel` | Target deployment platform (injected into PRD prompt) |
| `ALLOWED_STACKS` | Node.js/TS variants | Allowed tech stacks for PRD generation |
| `PIPELINE_APP_ID` | `2995372` | GitHub App ID used for autonomous write actions |
| `PIPELINE_APP_PRIVATE_KEY` | — | GitHub App private key PEM |
| `PIPELINE_APP_PRIVATE_KEY_FILE` | `~/Downloads/prd-to-prod-pipeline.2026-03-02.private-key.pem` | Fallback private key path if the PEM is not exported inline |
| `PIPELINE_BOT_LOGIN` | `prd-to-prod-pipeline` | Trusted App login for review verdict comments |
| `PIPELINE_TEMPLATE_SOURCE_DIR` | — | Optional local template source used for smoke runs or local template validation |
| `OPENROUTER_API_KEY` | — | OpenRouter API key for Claude |
| `COPILOT_GITHUB_TOKEN` | — | Fine-grained PAT with Copilot permission |
| `VERCEL_TOKEN` | — | Vercel API token for auto-deploy |
| `VERCEL_ORG_ID` | — | Vercel org/team identifier used during bootstrap |

## What's real vs. mocked

| Component | Default (mock) | Live (`WORKIQ_LIVE=true`) |
|-----------|---------------|--------------------------|
| Meeting data | Static fixture | Live via WorkIQ MCP + M365 |
| PRD extraction | **Real** — Claude generates from transcript | Same |
| Validation | **Real** — structural + tech stack checks | Same |
| Repo creation | **Real** — `gh repo create --template` | Same |
| Implementation | **Real** — Copilot agent writes code + tests | Same |
| Deployment | **Real** — auto-deploy to Vercel on merge | Same |

The only mock is the input by default. Everything from PRD extraction onward is the real pipeline, but the March 7, 2026 live run exposed auth-chain gaps that required manual merges; those gaps are what the current hardening work addresses.

## Project structure

```
meeting-to-main/
├── mocks/                        # WorkIQ mock layer
│   ├── transcript.json           # Realistic 31-turn meeting transcript
│   └── workiq-response.txt       # Prose meeting summary (pipeline input)
├── extraction/                   # PRD extraction layer
│   ├── extract-prd.sh            # Entry point — chains all three layers
│   ├── prompt.md                 # LLM prompt with platform constraints
│   ├── validate.sh               # Structural + tech stack validation
│   ├── workiq-client.ts          # Live WorkIQ MCP client (WORKIQ_LIVE=true)
│   └── test-fixtures/            # Valid/invalid PRDs for testing
├── trigger/                      # Pipeline trigger layer
│   ├── push-to-pipeline.sh       # Creates repo, validates bootstrap, provisions secrets, triggers /decompose
│   ├── smoke-pipeline.sh         # Disposable smoke run that waits for PR/review automation
│   └── smoke-prd.md              # Minimal PRD fixture for smoke runs
├── docs/                         # Design docs and plans
└── README.md
```

## Notes

- [`docs/run-log-2026-03-07-live.md`](/Users/skahessay/Documents/Projects/active/meeting-to-main/docs/run-log-2026-03-07-live.md) is the authoritative record of the March 7, 2026 live WorkIQ run.
- `docs/run-notes.md` is referenced in older notes but does not exist in this workspace.
