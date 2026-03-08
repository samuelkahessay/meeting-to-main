# meeting-to-main

Meeting transcript in. Deployed API out. Zero humans touching a keyboard.

```bash
source ~/.env && ./extraction/extract-prd.sh
```

One command takes a Teams meeting transcript, extracts a structured PRD using Claude, spins up a fresh repo, triggers an autonomous pipeline that implements, tests, and merges — then **auto-deploys to Vercel**.

**Live proof:** [team-availability-service.vercel.app](https://team-availability-service.vercel.app) — built entirely from a meeting transcript.

## How it works

```
Teams Meeting → WorkIQ MCP → Claude extracts PRD → New repo from template
    → /decompose → repo-assist builds it → PR merged → Vercel deploy
```

The pipeline has three layers, each a directory:

- **`mocks/`** — A realistic 31-turn meeting transcript and WorkIQ prose summary. Swap for live WorkIQ data with `WORKIQ_LIVE=true`.
- **`extraction/`** — Claude (via OpenRouter) transforms the meeting summary into a validated PRD. Structural checks and tech stack guards catch issues before anything ships.
- **`trigger/`** — Creates a fresh repo from [`prd-to-prod-template`](https://github.com/samuelkahessay/prd-to-prod-template), provisions secrets (pipeline + Vercel), files the PRD as a `[Pipeline]` issue, comments `/decompose`, and the pipeline takes over.

## Running it

The default path uses mock data — no M365 tenant needed:

```bash
# Prerequisites: OPENROUTER_API_KEY, COPILOT_GITHUB_TOKEN, VERCEL_TOKEN in ~/.env
# gh CLI authenticated
source ~/.env
./extraction/extract-prd.sh
```

For live Teams data via [WorkIQ](https://github.com/microsoft/workiq) MCP:

```bash
source ~/.env
WORKIQ_LIVE=true ./extraction/extract-prd.sh "Product Sync March 3rd"
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `WORKIQ_LIVE` | `false` | Set `true` to use live M365 meeting data |
| `DEPLOY_PLATFORM` | `Vercel` | Target deployment platform (injected into PRD prompt) |
| `ALLOWED_STACKS` | Node.js/TS variants | Allowed tech stacks for PRD generation |
| `OPENROUTER_API_KEY` | — | OpenRouter API key for Claude |
| `COPILOT_GITHUB_TOKEN` | — | Fine-grained PAT with Copilot permission |
| `VERCEL_TOKEN` | — | Vercel API token for auto-deploy |

## What's real vs. mocked

| Component | Default (mock) | Live (`WORKIQ_LIVE=true`) |
|-----------|---------------|--------------------------|
| Meeting data | Static fixture | Live via WorkIQ MCP + M365 |
| PRD extraction | **Real** — Claude generates from transcript | Same |
| Validation | **Real** — structural + tech stack checks | Same |
| Repo creation | **Real** — `gh repo create --template` | Same |
| Implementation | **Real** — Copilot agent writes code + tests | Same |
| Deployment | **Real** — auto-deploy to Vercel on merge | Same |

The only mock is the input. Everything from PRD extraction onward is the real pipeline.

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
│   └── push-to-pipeline.sh       # Creates repo, provisions secrets, triggers /decompose
├── docs/                         # Design docs and plans
└── README.md
```
