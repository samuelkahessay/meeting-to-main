# meeting-to-main

Meeting transcript in. Deployed API out.

```bash
source ~/.env && ./extraction/extract-prd.sh
```

One command pulls a Teams meeting transcript via [WorkIQ](https://github.com/microsoft/workiq) MCP, extracts a structured PRD using Claude, spins up a fresh repo, and triggers the autonomous implementation lane — ending with a **live deploy to Vercel**.

**Live proof:** [team-availability-service.vercel.app](https://team-availability-service.vercel.app) — fully autonomous end-to-end run. A second app ([to-do-app](https://to-do-app-with-weather-and-notifica.vercel.app)) was produced from a real WorkIQ transcript; its merge lane required manual recovery during the March 7, 2026 run.

## How it works

```
Teams Meeting → WorkIQ MCP → Claude extracts PRD → New repo from template
    → /decompose → repo-assist builds it → PR merged → Vercel deploy
```

The pipeline has three layers, each a directory:

- **`extraction/`** — Connects to Teams via WorkIQ MCP, pulls a meeting transcript, and has Claude (via OpenRouter) transform it into a validated PRD. Structural checks and tech stack guards catch issues before anything ships.
- **`trigger/`** — Creates a fresh repo from [`prd-to-prod-template`](https://github.com/samuelkahessay/prd-to-prod-template), provisions secrets/variables (pipeline + Vercel), validates bootstrap state, files the PRD as a `[Pipeline]` issue, and comments `/decompose`.
- **`mocks/`** — Offline development fixtures (transcript + summary) so the pipeline can be tested without an M365 tenant.

## Running it

Point it at a Teams meeting and go:

```bash
# Prerequisites: OPENROUTER_API_KEY, COPILOT_GITHUB_TOKEN, VERCEL_TOKEN,
# VERCEL_ORG_ID, PIPELINE_APP_PRIVATE_KEY in ~/.env
# gh CLI authenticated, WorkIQ MCP configured for M365 tenant
source ~/.env
WORKIQ_LIVE=true ./extraction/extract-prd.sh "Product Sync March 3rd"
```

For offline development (no M365 tenant needed):

```bash
source ~/.env
./extraction/extract-prd.sh
```

For a disposable autonomy smoke run against a template snapshot:

```bash
source ~/.env
PIPELINE_TEMPLATE_SOURCE_DIR=/path/to/prd-to-prod-template ./trigger/smoke-pipeline.sh
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `WORKIQ_LIVE` | — | Set `true` for live Teams data via WorkIQ MCP. Omit to use offline fixtures. |
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

## Pipeline stages

| Stage | What happens |
|-------|-------------|
| Meeting data | Pulled live from Teams via WorkIQ MCP (or offline fixtures for development) |
| PRD extraction | Claude generates a structured PRD from the transcript |
| Validation | Structural + tech stack checks before anything ships |
| Repo creation | `gh repo create --template` from [prd-to-prod-template](https://github.com/samuelkahessay/prd-to-prod-template) |
| Implementation | Copilot agent decomposes PRD into issues, writes code + tests, opens PRs |
| Review + merge | Autonomous review agent → auto-merge on approval |
| Deployment | Auto-deploy to Vercel on merge |

## Project structure

```
meeting-to-main/
├── mocks/                        # Offline development fixtures
│   ├── transcript.json           # Sample 31-turn meeting transcript
│   └── workiq-response.txt       # Sample meeting summary
├── extraction/                   # PRD extraction layer
│   ├── extract-prd.sh            # Entry point — pulls transcript, extracts PRD, triggers pipeline
│   ├── prompt.md                 # LLM prompt with platform constraints
│   ├── validate.sh               # Structural + tech stack validation
│   ├── workiq-client.ts          # WorkIQ MCP client for live Teams data
│   └── test-fixtures/            # Valid/invalid PRDs for testing
├── trigger/                      # Pipeline trigger layer
│   ├── push-to-pipeline.sh       # Creates repo, provisions secrets, validates bootstrap, triggers /decompose
│   ├── smoke-pipeline.sh         # Disposable end-to-end smoke run
│   └── smoke-prd.md              # Minimal PRD fixture for smoke runs
├── docs/                         # Design docs and plans
└── README.md
```

## Notes

- The March 7, 2026 live WorkIQ run log is available in `docs/run-log-2026-03-07-live.md` (not tracked — internal design doc).
- `docs/run-notes.md` is referenced in older notes but does not exist in this workspace.
