[← Back to README](../README.md)

## Feeding Project Knowledge Into the PRD and Architecture

Before running `/ideate` or `/spec`, you may already have useful material — a product brief you wrote in Google Docs, competitive research, API vendor documentation, stakeholder meeting notes, prior architectural decisions. This section explains how to get that content in front of Claude.

### Option 1 — Local files in `docs/project/` (recommended)

Create a `docs/project/` folder and drop any upstream inputs there before running `/ideate` or `/spec`. Both skills check this folder automatically on activation and read everything in it.

```
docs/project/
  decisions.md          ← the decision ledger — skill-owned, not a raw input (see /decision-log)
  brief.md              ← product vision, stakeholder requirements
  research.md           ← competitive analysis, user research
  api-vendor-notes.md   ← third-party API docs or constraints
  prior-adr.md          ← architecture decisions already made
  meeting-notes.md      ← anything from planning sessions
```

Any format works — `.md`, `.txt`, even a raw paste saved as a file. Claude reads them all and uses them to seed the decision log and pre-populate the rendered docs. You won't be asked to re-explain what's already there.

**This is also the right place for iterative notes.** If you've been drafting ideas in a separate Claude chat, copy the useful output into a file in `docs/project/` before starting the formal skill run.

### When upstream inputs change mid-project

If you update a file in `docs/project/` after implementation has already started, the flow is:

1. Update the file in `docs/project/`
2. Run `/spec prd` — it reads the changed file, updates `docs/prd.md`, then scans `docs/epics/` for any `in-progress` or `done` stories written against the old PRD
3. If affected stories exist, run `/correct-course` — it logs the trigger to the decision log, updates downstream docs, and schedules any remediation work as new stories in the right epic

`/correct-course` does **not** re-scan `docs/project/` itself. The trigger is always a known change you've already identified — `/spec`'s update flow surfaces the downstream impact.

### Option 2 — MCP-connected sources (Google Drive, Notion, etc.)

If you have an MCP server connected (Google Drive, Notion, Confluence, etc.), fetch the relevant documents **at the start of the session, before invoking the skill**:

1. Open a new Claude Code session.
2. Ask Claude to fetch the document via MCP: *"Read my product brief from Google Drive at [file name or URL]."*
3. Once Claude confirms it has the content, run `/ideate` or `/spec` in the same session — the fetched content is already in context.

Alternatively, download the file locally and save it to `docs/project/` — then it's persistent across sessions and doesn't require re-fetching each time.

> **Prefer `docs/project/` over re-fetching via MCP each session.** MCP fetches cost tokens every time and require the external service to be available. A local copy in `docs/project/` is free to re-read and works offline.

### Option 3 — Paste directly into the session

For one-off content that doesn't need to persist, paste it into the chat before running the skill:

*"Here's the product brief from our planning doc: [paste]. Now run `/spec prd`."*

Claude will use it for that session. It won't be available in future sessions unless you save it to `docs/project/`.

### What belongs in `docs/project/` vs `docs/prd.md`

| `docs/project/` | `docs/prd.md` |
|-----------------|---------------|
| Raw inputs — briefs, research, notes, exports | Distilled output — the canonical PRD |
| Written by humans, messy is fine | Rendered by `/spec` from the decision log, structured |
| Read once during PRD/arch creation | Read every time the first story of a new epic is created |
| Never auto-generated or overwritten (except `decisions.md`, which the skills own) | Updated by `/spec`'s update flow and `/correct-course` |

Don't put everything into the PRD. Keep raw inputs in `docs/project/` so the PRD stays dense and implementation-focused.

---

## Session Hygiene — Start Fresh Between Phases

Context accumulates silently. If you run `/ideate` → `/spec` → `/epics` → `/create-story` all in one session, the planning docs sit in context for every subsequent message — even when only the cache is needed.

**Rule: start a new Claude Code session for each major phase.**

| Phase | What to do |
|-------|-----------|
| After an `/ideate` stretch | End session — the decision log persists, so any later session resumes the loop. |
| After `/spec` docs are approved | End session. New session for `/epics`. |
| After `/epics` is written | End session. New session for `/create-story`. |
| Each story | One session per story: `/create-story` → `/dev-story` (code-review runs inline at the end). |
| After each story is done | End session before starting the next story. |

**Mid-session:** If a `/dev-story` session is running long, use `/compact` after finishing a major task group (e.g., all backend work done, about to start frontend). This summarizes and compresses prior context without losing your place.
