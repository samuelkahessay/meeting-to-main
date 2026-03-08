# meeting-to-main: WorkIQ Integration Design

> Meeting transcript in. Merged PR out. No human touching a keyboard.

**Date:** 2026-03-04 (design) · 2026-03-08 (deployed)
**Status:** Implemented, verified, and live on Vercel
**Live proof:** https://team-availability-service.vercel.app

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      meeting-to-main repo                       │
│                                                                 │
│  ┌──────────────┐    ┌──────────────────┐    ┌──────────────┐  │
│  │  Mock Layer   │    │  Extraction Layer │    │ Trigger Layer │  │
│  │              │    │                  │    │              │  │
│  │ transcript   │───▶│ WorkIQ MCP call  │───▶│ gh issue     │  │
│  │ .json        │    │ (or mock fallback)│    │ create +     │  │
│  │              │    │       │          │    │ /decompose   │  │
│  │ workiq-      │    │       ▼          │    │              │  │
│  │ response.json│    │ PRD extraction   │    │      │       │  │
│  └──────────────┘    │ prompt + schema  │    │      ▼       │  │
│                      │ validation       │    │ prd-to-prod  │  │
│                      │       │          │    │ pipeline     │  │
│                      │       ▼          │    │ takes over   │  │
│                      │ validated PRD.md │    └──────────────┘  │
│                      └──────────────────┘                      │
└─────────────────────────────────────────────────────────────────┘
                                                      │
                                                      ▼
                              ┌──────────────────────────────────┐
                              │         prd-to-prod repo          │
                              │                                  │
                              │  Issue created ──▶ /decompose    │
                              │       ▼                          │
                              │  prd-decomposer ──▶ [Pipeline]  │
                              │  issues                          │
                              │       ▼                          │
                              │  auto-dispatch ──▶ repo-assist   │
                              │       ▼                          │
                              │  PR opened ──▶ pr-review-agent   │
                              │       ▼                          │
                              │  auto-merge (if green + approved)│
                              └──────────────────────────────────┘
```

**Component boundaries are physical directories:**

```
meeting-to-main/
├── mocks/                    # WorkIQ mock layer (fixture data)
│   ├── transcript.json       # Realistic meeting transcript
│   └── workiq-response.txt   # Prose meeting summary (WorkIQ output shape)
├── extraction/               # PRD extraction layer
│   ├── extract-prd.sh        # Orchestrator script (entry point)
│   ├── workiq-client.ts      # Live WorkIQ MCP client (WORKIQ_LIVE=true path)
│   ├── prompt.md             # LLM prompt for transcript → PRD
│   └── validate.sh           # Structural PRD validation
├── trigger/                  # Pipeline trigger layer
│   └── push-to-pipeline.sh   # Creates issue + /decompose in prd-to-prod
├── docs/                     # Design & documentation
└── README.md
```

Three directories = three concerns. Daniel can point at each one.

---

## 2. WorkIQ Mock Strategy

### What WorkIQ MCP actually returns

WorkIQ is an MCP server (`workiq mcp`) that accepts natural-language queries against M365 data. For meeting transcripts, the call shape is:

```json
{
  "tool": "workiq",
  "method": "query",
  "params": {
    "query": "Get the full transcript from the product sync meeting on March 3rd",
    "scope": "meetings"
  }
}
```

Response shape (reconstructed from public WorkIQ documentation):

```json
{
  "source": "microsoft_teams_meeting",
  "meeting": {
    "title": "Product Sync — Sprint 14 Planning",
    "date": "2026-03-03T14:00:00Z",
    "duration_minutes": 32,
    "participants": ["Alice Chen (PM)", "Bob Rivera (Eng)", "Carol Wu (Design)"],
    "recording_available": true
  },
  "transcript": [
    {
      "speaker": "Alice Chen",
      "timestamp": "00:00:12",
      "text": "Let's kick off. We need to ship the notification preferences API this sprint."
    },
    {
      "speaker": "Bob Rivera",
      "timestamp": "00:00:45",
      "text": "I can scaffold Express + TypeScript. We'll need CRUD endpoints for user preferences, a batch endpoint for bulk updates, and webhook delivery."
    }
  ],
  "action_items": [
    "Ship notification preferences API with CRUD + batch + webhooks",
    "Use Express + TypeScript, Vitest for testing",
    "In-memory storage is fine for v1",
    "Must handle 500 preferences per batch request"
  ],
  "key_decisions": [
    "No database for v1 — in-memory Map is sufficient",
    "Webhook delivery is fire-and-forget, no retry queue",
    "REST over WebSocket for initial version"
  ]
}
```

### Mock implementation

**`mocks/transcript.json`** — A realistic 25-30 turn meeting transcript. Product-flavored, with natural speech patterns (interruptions, clarifications, scope debates). Not sanitized corporate-speak — it should feel like a real standup.

**`mocks/workiq-response.json`** — The full WorkIQ MCP response above, pre-populated with the transcript and extracted action items / key decisions.

**Why static fixtures are sufficient for demo:**
- Proves the data shape contract between WorkIQ and our extraction layer
- The extraction prompt works identically on mock or real data
- Swapping to real WorkIQ = change one `if` branch in the script
- Daniel can inspect the fixture files and see exactly what M365 data flows through

### Live WorkIQ path (`WORKIQ_LIVE=true`)

The live path is opt-in, not auto-detected. Set `WORKIQ_LIVE=true` to use it:

```bash
WORKIQ_LIVE=true ./extraction/extract-prd.sh "Product Sync March 3rd"
```

In `extract-prd.sh`:

```bash
if [ "${WORKIQ_LIVE:-}" = "true" ]; then
  WORKIQ_OUTPUT=$(npx tsx "$PROJECT_ROOT/extraction/workiq-client.ts" "${1:-Product Sync}")
  echo "      Using live WorkIQ MCP"
else
  WORKIQ_OUTPUT=$(cat "$PROJECT_ROOT/mocks/workiq-response.txt")
  echo "      Using mock WorkIQ data"
fi
```

`extraction/workiq-client.ts` handles the full MCP lifecycle:

1. Spawns `npx -y @microsoft/workiq mcp` as a stdio child process
2. MCP handshake (`initialize`)
3. Tool discovery (`tools/list`) — selects from `query`, `search_meetings`, `get_meeting_transcript`, `meetings`, or the first available tool
4. Data fetch (`tools/call`) with the meeting query as the argument
5. Prints prose to stdout — identical contract to `mocks/workiq-response.txt`

Entra ID device-code auth (first run only) goes to stderr so it appears in the terminal without polluting the captured `WORKIQ_OUTPUT`.

**Why opt-in, not auto-detected:** Auto-detecting the `workiq` binary can silently hit a half-installed CLI and fail in confusing ways. An explicit env-var flag makes the intent clear and keeps the demo path friction-free.

---

## 3. PRD Extraction Layer

### The prompt

The extraction layer takes WorkIQ output (meeting transcript + action items + decisions) and produces a PRD that conforms exactly to prd-to-prod's schema.

**`extraction/prompt.md`:**

````markdown
You are a PRD extraction agent. You receive a meeting transcript with action items
and key decisions. Your job is to produce a PRD markdown document that conforms
EXACTLY to the schema below.

## Rules

1. Extract ONLY what was discussed. Do not invent features not mentioned.
2. Every feature must have testable acceptance criteria as markdown checkboxes.
3. Tech stack must be explicitly stated in the meeting or inferred from
   clear technical discussion. If ambiguous, default to Node.js + TypeScript.
4. Features must be ordered by dependency (scaffold first, then data layer,
   then endpoints, then UI).
5. Include "Validation Commands" section with build/test/run commands.
6. Include "Non-Functional Requirements" and "Out of Scope" sections.
7. The PRD must be self-contained — an agent with no meeting context must be
   able to implement it from the PRD alone.

## Output Schema

```markdown
# PRD: [Project Name]

## Overview
[2-3 sentences: what this builds, why, deployment model]

## Tech Stack
- Runtime: [e.g., Node.js 20+]
- Framework: [e.g., Express.js]
- Language: [e.g., TypeScript]
- Testing: [e.g., Vitest]
- Storage: [e.g., In-memory (Map)]

## Validation Commands
- Build: [command]
- Test: [command]
- Run: [command]

## Features

### Feature 1: [Title]
[Description paragraph]

**Acceptance Criteria:**
- [ ] [Specific, testable requirement]
- [ ] [Another requirement]

### Feature N: ...

## Non-Functional Requirements
- [Requirement]

## Out of Scope
- [What's explicitly excluded]
```

## Input

Meeting transcript and extracted context:

{workiq_output}
````

### Validation

Before the PRD triggers the pipeline, it passes two checks:

1. **Structural validation** — The script checks for required sections:
   - `# PRD:` title exists
   - `## Tech Stack` section exists
   - `## Features` section exists with at least one `### Feature`
   - Each feature has `**Acceptance Criteria:**` with at least one `- [ ]` checkbox
   - `## Validation Commands` section exists

2. **Schema conformance** — A simple grep-based check (no external dependencies):
   ```bash
   validate_prd() {
     local prd="$1"
     local errors=0

     grep -q "^# PRD:" "$prd"           || { echo "FAIL: Missing PRD title"; ((errors++)); }
     grep -q "^## Tech Stack" "$prd"     || { echo "FAIL: Missing Tech Stack"; ((errors++)); }
     grep -q "^## Features" "$prd"       || { echo "FAIL: Missing Features"; ((errors++)); }
     grep -q "^### Feature 1:" "$prd"    || { echo "FAIL: Missing Feature 1"; ((errors++)); }
     grep -q "^\- \[ \]" "$prd"          || { echo "FAIL: No acceptance criteria"; ((errors++)); }
     grep -q "^## Validation Commands" "$prd" || { echo "FAIL: Missing Validation Commands"; ((errors++)); }

     return $errors
   }
   ```

### LLM call

The extraction uses Claude (via `claude` CLI or API) to transform WorkIQ output into a PRD. The script:

```bash
# Generate PRD from WorkIQ output using Claude
PROMPT=$(cat extraction/prompt.md)
PROMPT="${PROMPT//\{workiq_output\}/$WORKIQ_OUTPUT}"

curl -s https://openrouter.ai/api/v1/chat/completions ... > generated-prd.md

# Validate
validate_prd generated-prd.md || { echo "PRD validation failed"; exit 1; }
```

**Why Claude CLI, not a custom script:** The extraction is inherently an LLM task — mapping unstructured conversation to structured spec. A rule-based approach would be brittle and miss nuance. The prompt is the engineering artifact; it's readable, versionable, and tunable.

---

## 4. Trigger Mechanism

Once the PRD is validated, the trigger layer creates a **fresh repo from a template** and files the PRD as an issue with `/decompose`. Each meeting gets its own isolated repo — no collision with existing projects.

**`trigger/push-to-pipeline.sh`:**

1. Derives a repo name from the PRD title (e.g., `weather-todo-app-with-notification-preferences`)
2. Creates `samuelkahessay/<repo-name>` from the `prd-to-prod-template` GitHub template
3. Creates the PRD issue and comments `/decompose`

**Why this approach:**
- Each PRD gets a clean repo — no polluting an existing codebase
- `/decompose` is the pipeline's real entry point — no new workflows needed
- The `[Pipeline]` title prefix activates auto-dispatch
- The `pipeline` label enables routing
- Template repo (`prd-to-prod-template`) carries all the GitHub Actions workflows

### End-to-end orchestrator

**`extraction/extract-prd.sh`** ties all three layers together:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== meeting-to-main ==="
echo ""

# Step 1: WorkIQ extraction (or mock)
echo "[1/3] Fetching meeting data via WorkIQ..."
if command -v workiq &>/dev/null && workiq mcp --health 2>/dev/null; then
  WORKIQ_OUTPUT=$(workiq mcp query "Get transcript from '${1:-Product Sync}'")
  echo "      Using live WorkIQ MCP"
else
  WORKIQ_OUTPUT=$(cat mocks/workiq-response.json)
  echo "      Using mock WorkIQ data"
fi

# Step 2: PRD extraction via LLM
echo "[2/3] Extracting PRD from meeting transcript..."
PROMPT=$(cat extraction/prompt.md)
PROMPT="${PROMPT//\{workiq_output\}/$WORKIQ_OUTPUT}"
curl -s https://openrouter.ai/api/v1/chat/completions ... > generated-prd.md
echo "      PRD written to generated-prd.md"

# Validate
source extraction/validate.sh
validate_prd generated-prd.md
echo "      PRD validation passed"

# Step 3: Trigger pipeline
echo "[3/3] Creating pipeline repo and triggering /decompose..."
bash trigger/push-to-pipeline.sh generated-prd.md

echo ""
echo "=== Done. Watch the new repo for pipeline activity. ==="
```

**One command to run the entire demo:**

```bash
./extraction/extract-prd.sh
```

---

## 5. Demo Script (60-second screen recording)

### Setup (before recording)

- Terminal open, `meeting-to-main` repo visible
- GitHub open in browser tab
- Screen recording tool ready

### Recording — beat by beat

| Time | What's on screen | What's happening |
|------|-----------------|-----------------|
| 0:00-0:05 | Terminal: `cat mocks/transcript.json \| jq '.transcript[:3]'` | Show the meeting transcript — real people discussing a feature |
| 0:05-0:08 | Terminal: `cat mocks/workiq-response.txt` | Show the WorkIQ prose summary the pipeline will consume |
| 0:08-0:12 | Terminal: `./extraction/extract-prd.sh` | Run the pipeline. Step [1/3] shows "Using mock WorkIQ data" |
| 0:12-0:20 | Terminal: Steps [2/3] and [3/3] complete | PRD extracted, validated, issue created. URL printed. |
| 0:20-0:25 | Terminal: `cat generated-prd.md \| head -30` | Show the generated PRD — structured, with features and acceptance criteria |
| 0:25-0:30 | Browser: Click the issue URL | Show the GitHub issue with full PRD body and `/decompose` comment |
| 0:30-0:40 | Browser: Refresh issue page | prd-decomposer has fired — child [Pipeline] issues appear as referenced |
| 0:40-0:50 | Browser: Click into Actions tab or a child issue | Show repo-assist running, implementing features |
| 0:50-0:55 | Browser: Pull Requests tab | Show PR(s) opened by the pipeline, CI running |
| 0:55-0:60 | Browser: PR detail page — green checks, review approved | The seam is complete: meeting → merged PR |

### Fallback timing

If the pipeline hasn't fully completed in 60 seconds (decomposition + implementation takes ~5-10 min), the recording can:
- Show the first 30 seconds live (transcript → issue created → decompose triggered)
- Cut to "3 minutes later..." showing decomposed issues
- Cut to "8 minutes later..." showing open PR with green CI

This is honest — it shows real async pipeline behavior, not a fake instant result.

---

## 6. Gaps and Risks

### What's mocked vs. real

| Component | Demo state | Production state |
|-----------|-----------|-----------------|
| Meeting transcript | Static fixture (`mocks/transcript.json`) | Live from Teams via WorkIQ MCP |
| WorkIQ MCP call | Bypassed, reads fixture file | `workiq mcp query "..."` |
| PRD extraction (LLM) | **Real** — Claude generates PRD from transcript | Same |
| PRD validation | **Real** — structural checks run | Same, potentially stricter |
| GitHub issue creation | **Real** — `gh issue create` | Same |
| `/decompose` trigger | **Real** — actual slash command | Same |
| prd-to-prod pipeline | **Real** — full pipeline runs | Same |

**Key point for Daniel:** The only mock is the input data source. Everything from PRD extraction onward is the real pipeline.

### What requires M365 admin consent

| Capability | Consent needed | Our workaround |
|-----------|---------------|----------------|
| Read meeting transcripts | Yes — `OnlineMeetingTranscript.Read.All` | Mock fixture |
| Read Teams messages | Yes — `ChannelMessage.Read.All` | Mock fixture |
| Read user calendar | Yes — `Calendars.Read` | Mock fixture |
| WorkIQ MCP server (`workiq mcp`) | Requires M365 tenant + admin consent for the above scopes | Bypass entirely, use fixtures |

**Upgrade path:** When admin consent is available, run with `WORKIQ_LIVE=true ./extraction/extract-prd.sh "your meeting name"`. No code changes needed.

### What Daniel Meppiel would ask

1. **"How does WorkIQ handle multi-topic meetings?"**
   - The extraction prompt asks for a single PRD per meeting. For meetings covering multiple projects, the prompt would need to split into multiple PRDs or the user specifies which topic. Design doc punts on this — it's a prompt engineering problem, not an architecture problem.

2. **"What happens when the transcript is ambiguous about tech stack?"**
   - The prompt defaults to Node.js + TypeScript if not explicitly discussed. The validation step catches missing Tech Stack sections. A more robust version could ask for human confirmation on ambiguous choices.

3. **"Can this work with Copilot Studio / Power Automate instead of a shell script?"**
   - Yes. The three layers are decoupled. The trigger layer's `gh issue create` + `gh issue comment` could be Power Automate HTTP actions. The extraction prompt could run in Copilot Studio with a Claude connector. The design is tool-agnostic.

4. **"What about meeting recordings vs. transcripts?"**
   - WorkIQ supports both, but transcripts are text-native and better for LLM extraction. Recordings would need speech-to-text first. The mock fixtures model the transcript path.

5. **"How do you handle PRD quality? What if the meeting was vague?"**
   - The validation layer catches structural failures (missing sections, no acceptance criteria). It does NOT catch semantic quality (vague requirements, impossible acceptance criteria). A future version could add a review step before triggering the pipeline.

6. **"What's the latency end-to-end?"**
   - WorkIQ query: ~2-5s (mocked: instant)
   - PRD extraction (Claude): ~10-20s
   - Issue creation + /decompose: ~3s
   - prd-to-prod pipeline (decompose → implement → PR): ~5-15 min
   - **Total: ~6-16 minutes from meeting data to open PR**

### Risks to demo success

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Claude CLI not available in demo env | Low | Can use API directly with curl |
| `gh` CLI auth fails | Low | Pre-authenticate, test before recording |
| prd-to-prod pipeline is mid-run on another project | Medium | Check pipeline status before demo; use `PIPELINE_HEALING_ENABLED` toggle |
| PRD extraction produces invalid PRD | Low | Validation catches it; re-run with tweaked prompt |
| GitHub Actions quota / rate limits | Low | Free tier has 2000 min/month; demo uses ~15 min |
| Meeting transcript too short/simple → trivial PRD → unimpressive demo | Medium | Craft the mock transcript carefully — it should produce a 4-5 feature PRD |

---

## Appendix: Mock Transcript Content

The mock transcript should describe building a **Notification Preferences API** — a realistic but small project (4-5 features) that exercises the full pipeline. Participants discuss:

- CRUD endpoints for user notification preferences
- Batch update endpoint (up to 500 preferences per request)
- Webhook delivery for preference changes (fire-and-forget)
- Express + TypeScript + Vitest stack
- In-memory storage for v1
- Explicit scope: no auth, no database, no retry queue

This produces a PRD similar in complexity to prd-to-prod's `sample-prd.md` — proven to work through the pipeline in a single run.
