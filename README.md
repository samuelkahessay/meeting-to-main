# meeting-to-main

Meeting transcript in. Merged PR out. Zero humans touching a keyboard.

```bash
./extraction/extract-prd.sh
```

One command takes a Teams meeting transcript, extracts a structured PRD using Claude, spins up a fresh repo, and triggers an autonomous pipeline that decomposes, implements, tests, and opens a PR — end to end, no manual steps.

## What just happened

```
Teams Meeting → WorkIQ MCP → Claude extracts PRD → New repo from template → /decompose → repo-assist builds it → PR opened
```

The pipeline has three layers, each a directory:

- **`mocks/`** — A realistic 31-turn meeting transcript and WorkIQ prose summary. Swap for live WorkIQ data with `WORKIQ_LIVE=true`.
- **`extraction/`** — Claude (via OpenRouter) transforms the meeting summary into a validated PRD. Grep-based structural checks catch missing sections before anything ships.
- **`trigger/`** — Creates a fresh repo from [`prd-to-prod-template`](https://github.com/samuelkahessay/prd-to-prod-template), files the PRD as a `[Pipeline]` issue, comments `/decompose`, and the pipeline takes over.

## Live demo

The default path uses mock data — no M365 tenant needed:

```bash
# Prerequisites: OPENROUTER_API_KEY in ~/.env, gh CLI authenticated
source ~/.env
./extraction/extract-prd.sh
```

For live Teams data via [WorkIQ](https://github.com/microsoft/workiq) MCP:

```bash
WORKIQ_LIVE=true ./extraction/extract-prd.sh "Product Sync March 3rd"
```

## What's real vs. mocked

| Component | Default (mock) | Live (`WORKIQ_LIVE=true`) |
|-----------|---------------|--------------------------|
| Meeting data | Static fixture | Live via WorkIQ MCP + M365 |
| PRD extraction | **Real** — Claude generates from transcript | Same |
| Validation | **Real** — structural checks | Same |
| Repo creation | **Real** — `gh repo create --template` | Same |
| Implementation | **Real** — Copilot agent writes code + tests | Same |

The only mock is the input. Everything from PRD extraction onward is the real pipeline.
