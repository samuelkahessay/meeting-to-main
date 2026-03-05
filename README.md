# meeting-to-main

> Meeting transcript in. Merged PR out. No human touching a keyboard.

Takes a meeting transcript (via [WorkIQ](https://workiq.com) MCP), extracts a structured PRD using Claude, and feeds it into [prd-to-prod](https://github.com/skahessay/prd-to-prod) for automated decomposition, implementation, and merge.

## How it works

```
Meeting Transcript (WorkIQ) -> PRD Extraction (Claude) -> Pipeline Trigger (GitHub Issue)
```

1. **Mock/WorkIQ layer** (`mocks/`) — Static meeting data (transcript + WorkIQ prose summary), or live WorkIQ MCP call
2. **Extraction layer** (`extraction/`) — Claude transforms WorkIQ's meeting summary into a validated PRD
3. **Trigger layer** (`trigger/`) — Creates a GitHub issue in prd-to-prod with `/decompose`

## Quick start

```bash
# Prerequisites: claude CLI, gh CLI (authenticated), Node.js (for live path)

# Run with mock data (default — no M365 connection needed)
./extraction/extract-prd.sh

# Run with live WorkIQ MCP (requires M365 tenant + admin consent)
WORKIQ_LIVE=true ./extraction/extract-prd.sh "Product Sync March 3rd"

# Or run each step manually:
cat mocks/workiq-response.txt                     # 1. View mock meeting data
claude --print "$(cat extraction/prompt.md)"       # 2. Extract PRD
bash trigger/push-to-pipeline.sh generated-prd.md # 3. Trigger pipeline
```

## Project structure

```
meeting-to-main/
├── mocks/                        # WorkIQ mock layer
│   ├── transcript.json           # Realistic 31-turn meeting transcript
│   └── workiq-response.txt       # WorkIQ prose summary of the meeting
├── extraction/                   # PRD extraction layer
│   ├── extract-prd.sh            # Main orchestrator (entry point)
│   ├── workiq-client.ts          # Live WorkIQ MCP client (used when WORKIQ_LIVE=true)
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
| `WORKIQ_LIVE` | unset | Set to `true` to use live WorkIQ MCP instead of mock data |
| `PIPELINE_REPO` | `skahessay/prd-to-prod` | Target repo for pipeline trigger |

## Live WorkIQ path

When `WORKIQ_LIVE=true`, `extraction/workiq-client.ts` is invoked via `npx tsx` (no build step). It:

1. Spawns `@microsoft/workiq mcp` as a stdio child process
2. Performs the MCP handshake and calls `tools/list` to discover available tools
3. Calls the appropriate tool with the meeting query
4. Prints prose to stdout — identical contract to `mocks/workiq-response.txt`

On first run, WorkIQ will prompt for Entra ID device-code authentication. Subsequent runs reuse the cached token. Auth prompts go to stderr and don't affect the captured output.

**M365 permissions required:** `OnlineMeetingTranscript.Read.All` (and optionally `ChannelMessage.Read.All`, `Calendars.Read` for broader queries).

## What's mocked vs. real

| Component | Mock (default) | Live (`WORKIQ_LIVE=true`) |
|-----------|----------------|--------------------------|
| Meeting data | `mocks/workiq-response.txt` | Live via `@microsoft/workiq mcp` |
| PRD extraction (Claude) | Real | Real |
| PRD validation | Real | Real |
| GitHub issue creation | Real | Real |
| prd-to-prod pipeline | Real | Real |
