# meeting-to-main

> Meeting transcript in. Merged PR out. No human touching a keyboard.

Takes a meeting transcript (via [WorkIQ](https://workiq.com) MCP), extracts a structured PRD using Claude, and feeds it into [prd-to-prod](https://github.com/skahessay/prd-to-prod) for automated decomposition, implementation, and merge.

## How it works

```
Meeting Transcript (WorkIQ) -> PRD Extraction (Claude) -> Pipeline Trigger (GitHub Issue)
```

1. **Mock/WorkIQ layer** (`mocks/`) — Static meeting transcript fixture, or live WorkIQ MCP call
2. **Extraction layer** (`extraction/`) — Claude transforms transcript into a validated PRD
3. **Trigger layer** (`trigger/`) — Creates a GitHub issue in prd-to-prod with `/decompose`

## Quick start

```bash
# Prerequisites: claude CLI, gh CLI (authenticated)

# Run the full pipeline (uses mock data)
./extraction/extract-prd.sh

# Or run each step manually:
cat mocks/workiq-response.json                    # 1. View meeting data
claude --print "$(cat extraction/prompt.md)"       # 2. Extract PRD
bash trigger/push-to-pipeline.sh generated-prd.md # 3. Trigger pipeline
```

## Project structure

```
meeting-to-main/
├── mocks/                        # WorkIQ mock layer
│   ├── transcript.json           # Realistic 30-turn meeting transcript
│   └── workiq-response.json      # Full WorkIQ MCP response envelope
├── extraction/                   # PRD extraction layer
│   ├── extract-prd.sh            # Main orchestrator (entry point)
│   ├── prompt.md                 # LLM prompt for transcript -> PRD
│   ├── validate.sh               # Structural PRD validation
│   └── test-fixtures/            # Valid/invalid PRDs for testing validation
├── trigger/                      # Pipeline trigger layer
│   └── push-to-pipeline.sh       # Creates issue + /decompose in prd-to-prod
├── docs/                         # Design & planning docs
└── README.md
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PIPELINE_REPO` | `skahessay/prd-to-prod` | Target repo for pipeline trigger |

## What's mocked vs. real

| Component | Demo | Production |
|-----------|------|------------|
| Meeting transcript | Static fixture | Live via WorkIQ MCP |
| PRD extraction (Claude) | Real | Real |
| PRD validation | Real | Real |
| GitHub issue creation | Real | Real |
| prd-to-prod pipeline | Real | Real |
