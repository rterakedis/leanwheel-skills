---
name: story-flywheel
description: Run the full story development loop (create → dev → review) repeatedly until the epic is complete. Use when the user says "story flywheel", "run flywheel", or "run the loop".
---

# Story Flywheel Skill

**Goal:** Drive the epic to completion without manual story-by-story triggering. Automates create-story → dev-story → code-review in sequence, pausing only for human decisions and commit sign-off between stories.

**Iron rule:** Never start the next story until the user has committed and given explicit go-ahead.

---

## Activation

1. Determine which epic to run. Check in order:
   - Explicit argument: `/story-flywheel {epic_num}` or `/story-flywheel {epic_num}-{story_num}`
   - Active milestone with `in-progress` or `review` issues (resume in flight)
   - Lowest epic-numbered milestone that still has open issues (see epic discovery below)
   - Ask: "Which epic should I run the flywheel on?"

   **Epic discovery — sort by epic number in title, not by GitHub milestone ID:**
   GitHub milestone IDs are assigned in creation order and do not reflect intentional epic sequence. Epics may be reordered or inserted later, so always derive sequence from the number embedded in the milestone title (e.g., `"Epic 3 — ..."` → epic 3).
   ```bash
   # List all open milestones, extract epic number from title, sort by it, pick lowest
   gh api repos/{owner}/{repo}/milestones \
     --jq '[.[] | select(.open_issues > 0)
            | {title:.title, gh_num:.number,
               epic_num: (.title | capture("Epic (?P<n>[0-9]+)").n | tonumber)}]
           | sort_by(.epic_num) | .[0]'
   ```
   Use the returned `title` and `gh_num` for all subsequent milestone-scoped queries. If the title does not match the `"Epic N"` pattern, fall back to `docs/epics.md` ordering.

2. If a specific starting story was given, start there. Otherwise find the **first incomplete story** in the epic by querying within that milestone only:
   ```bash
   # Use milestone's GitHub number (gh_num) — never sort open issues globally
   gh api "repos/{owner}/{repo}/issues?milestone={gh_num}&state=open" \
     --jq '[.[] | select(all(.labels[]; .name != "in-progress") and all(.labels[]; .name != "review"))]
           | sort_by(.number) | .[0] | {number:.number, title:.title}'
   ```
   Fall back to reading `docs/epics.md` if GitHub unavailable.

3. Announce: "Starting flywheel for Epic {N}: {title}. {X} stories remaining. First up: {epic}.{story} — {story_title}."

4. **Determine delegation mode + model routing.** Set `swift_project = true` if `docs/setup/swift/` exists OR an `.xcodeproj` / `.xcworkspace` / `Package.swift` is present in the repo; otherwise `false`.

   Check whether the leanwheel subagents are available (the plugin ships `lw-story-creator`, `lw-story-developer`, `lw-story-reviewer` as agent types).
   - **Subagents available (default, preferred):** run in **subagent-delegation mode** — each phase is spawned as its subagent via the Agent tool, with the model selected automatically (see Subagent Delegation & Model Routing). No manual model switching. Announce once:
     > Running the flywheel with subagent delegation — each phase runs in its own context with its model chosen automatically (Conserve-Opus baseline{, Opus for dev-story since this is a Swift project if swift_project}). You'll only be asked to weigh in at clarifications, the per-story checkpoint, and epic boundaries.
   - **Subagents unavailable (fallback):** run inline and fall back to **manual model switching** (see Fallback: Manual Model Switching). Only Swift projects get switch gates; non-Swift runs fully automated on the current model.

---

## Subagent Delegation & Model Routing

Default mode. Each phase is delegated to its subagent via the Agent tool. Two wins on the Pro plan: **model routing is automatic** (no `/model` dance), and **context is isolated** — each phase's heavy doc/code reading happens in a throwaway subagent window, so this orchestrating thread only accumulates each subagent's short structured report, not three phases of file reads.

Per-phase routing (Conserve-Opus baseline, dynamic Swift exception):

| Phase | subagent_type | Python / Web | Swift / SwiftUI | Why |
|---|---|---|---|---|
| 1 — Create Story | `lw-story-creator` | Sonnet | Sonnet | Story authoring doesn't need Opus. |
| 2 — Dev Story | `lw-story-developer` | **Sonnet** | **Opus** | On Swift, a Sonnet pass tends to fail the Build & Test Gate and loop — each failed `xcodebuild` retry costs more than one accurate Opus pass, so Opus is the *token-conserving* choice. On Python/web, Sonnet passes first-try often enough that Opus is overspend. |
| 3 — Code Review | `lw-story-reviewer` | Sonnet | Sonnet | Adversarial reading; the Build & Test Gate is the correctness backstop, not the model. (Dev-story already runs an inline review — see Phase 3.) |

**How to set the model:** the subagent defs default to Sonnet. Pass a per-spawn `model` override on the Agent call **only** for Phase 2 when `swift_project = true` (`model: opus`). All other spawns use the default. If the user opts out for the run ("conserve everything", "stay on Sonnet"), drop the Opus override too and note it.

**Spawning a phase:** call the Agent tool with the phase's `subagent_type`, the model override if applicable, and a prompt containing the story identifier/path plus any context the subagent needs (it starts cold). Wait for the subagent's report, then act on its structured fields. Do **not** re-do the phase's work in this thread — the subagent owns it.

---

## Fallback: Manual Model Switching (only when subagents unavailable)

Used only when the leanwheel subagents can't be spawned. Active only when `swift_project = true`; non-Swift runs fully automated on the current model. The model can't change its own model — these are **hard stops** that wait for the user to switch it in the UI (`/model`), then confirm.

| Phase | Model | Why |
|---|---|---|
| 1 — Create Story | **Sonnet** | Cost-efficient for authoring. |
| 2 — Dev Story | **Opus** (high for concurrency / complex SwiftUI state) | Fewest build-gate iterations. |
| 3 — Code Review | **Sonnet** | Build & Test Gate is the backstop. |

A **MODEL SWITCH GATE** looks like:

```
─────────────────────────────────────────────
MODEL SWITCH — before {phase}
Set your model to: {model}
  • Run /model and select it
  • Type "ready" when switched
─────────────────────────────────────────────
```

Wait for "ready". If the user opts out ("just keep going"), honor it for the rest of the run. Skip a gate when the target already matches the last model set.

---

## The Loop

Repeat until the epic is complete (see **Exit Conditions**):

### Phase 1 — Create Story

**Subagent mode:** spawn `lw-story-creator` (default model: Sonnet) via the Agent tool. Prompt it with the story identifier (`{epic}.{story}`) so create-story skips identification.
**Fallback mode:** if `swift_project`, issue a MODEL SWITCH GATE for **Sonnet**, then execute `skills/create-story/skill.md` inline.

- Wait for the story file to be written and GitHub issue updated.
- From the subagent report, capture `STORY FILE`, `COMPLEXITY`, `CLARIFICATIONS NEEDED`, `PREREQUISITES`, `DESIGN GAP`.
- **Clarification surfacing:** if the report lists material clarifications (the subagent assumed defaults rather than guessing silently), present them to the user now as a human-decision pause before Phase 2 — this is the Clarification Gate surfacing at the orchestration layer. Record the user's answers back into the story file (or confirm the assumed defaults) before proceeding.
- Do not proceed to Phase 2 until the story file path is in hand and clarifications are resolved.

### Phase 2 — Dev Story

**Subagent mode:** spawn `lw-story-developer` via the Agent tool with the story file path. Pass `model: opus` **only if `swift_project`** (otherwise the default Sonnet). Instruct it to run the full dev-story workflow including the Build & Test Gate, the evals RUN (if `docs/evals/` exists), invariant/design verification, and the inline review.
**Fallback mode:** if `swift_project`, MODEL SWITCH GATE for **Opus**; then execute `skills/dev-story/skill.md` inline.

- Note: in subagent mode the developer subagent already runs dev-story's **inline** code review (Pass A–E). Phase 3 below becomes a *light confirmation* of its report rather than a second full review — only spawn a separate reviewer if the developer reported `UNRESOLVED` items or you want an independent adversarial pass.
- From the report capture `STATUS`, `BUILD & TEST`, `BUILD/TEST ITERATIONS`, `EVALS`, `FINDINGS`, `INVARIANTS`, `INFRA TOUCHED`, `UNRESOLVED`.
- **Operational doc sync (cheap, orchestrator-owned):** the developer does **not** run docs-sync (it would land on the dev model — Opus on Swift). If the report's `INFRA TOUCHED` is `yes`, spawn **`lw-docs-sync`** (Haiku) via the Agent tool with the story file path and op `OPERATIONAL`; capture its `DOCS UPDATED` return for the checkpoint/ledger. Skip the spawn entirely when `INFRA TOUCHED: no` (zero cost). Fallback if subagents are unavailable: execute the docs-sync OPERATIONAL op inline.
- Do not proceed until `STATUS` is `review`/`done` (or HALT).

**On HALT:** Stop the flywheel. Report: "Flywheel paused — dev-story halted on {epic}.{story}: {reason}. Resolve the blocker and resume with `/story-flywheel {epic}.{story}`."

### Phase 3 — Code Review

The developer subagent already ran the inline review in Phase 2. Decide:
- **Clean report (no `UNRESOLVED`, gate PASS):** skip a separate review pass — carry the Phase 2 findings/rubric straight into the checkpoint. (Saves a full extra review's tokens.)
- **`UNRESOLVED` items, FAIL gate, or security-sensitive story:** spawn `lw-story-reviewer` (default model: Sonnet) for an independent adversarial pass. **Fallback mode:** MODEL SWITCH GATE for **Sonnet**, then execute `skills/code-review/skill.md` inline.

When a separate review runs:
- Pass the story file path so it skips auto-detection.
- It runs Passes A–E, emits the **SCORE rubric line**, auto-patches `patch` findings, logs `defer` via the deferred skill, and **re-verifies green**.
- `decision-needed` findings surface in its report — present them to the user and wait for answers, then have the patches applied.

**On unresolvable patches:** Do not proceed to Phase 4. Leave story status `in-progress`, report which items need attention, and stop the flywheel. Resume with `/story-flywheel {epic}.{story}`.

### Phase 4 — Human Checkpoint

After code review completes, surface a consolidated checkpoint before any commit:

```
─────────────────────────────────────────────
STORY {epic}.{story} CHECKPOINT
─────────────────────────────────────────────
Status: code review complete

VERIFICATION
{Build & Test: green | manual-required | red} · {evals: P/T or n/a} · {rubric gate: PASS/FAIL or n/a} · {invariants: V/T or n/a} · build/test iterations: {n}

DECISIONS MADE THIS STORY
{list each [Decision] finding and the answer recorded — "none" if clean}

PATCHES APPLIED
{list each [Patch] auto-applied — "none" if clean}

DEFERRED ITEMS
{list each [Defer] item with its D-ID and scheduled story — "none" if clean}

TESTING PLAN
{derive from the story's ACs and changed code: list concrete manual steps the developer should perform before committing — e.g. tap/click paths through UI, API calls to exercise, edge cases to verify, data states to set up. If nothing user-visible changed (pure refactor, migration, test-only), write "none — no user-visible surface changed."}

UNRESOLVED ITEMS (action required before committing)
{list any [ ] findings that could not be auto-patched — empty means none}

─────────────────────────────────────────────
Review the changes above, then:
  • Commit when satisfied
  • Type "continue" to start the next story
  • Type "stop" to end the flywheel here
  • Type "retry" to re-run code review on this story
─────────────────────────────────────────────
```

**Observability:** before presenting the checkpoint, append a `story-flywheel` summary line to `docs/metrics/flywheel-ledger.jsonl` (if `docs/metrics/` exists) capturing this story's verification fields and per-phase models used. One shell-redirect append — never read the ledger into context. The per-phase `dev-story` / `code-review` lines are written by those skills/subagents; this is the story-level roll-up.

**Wait for user response.** Do not proceed until user explicitly types one of the above commands or equivalent.

- **"continue"** (or equivalent like "next", "go", "lgtm"): advance to next story
- **"stop"** (or equivalent like "done", "pause", "exit"): exit flywheel gracefully (see Exit)
- **"retry"**: re-run `skills/code-review/skill.md` on the current story, then show checkpoint again

If unresolved items exist, note them prominently in the checkpoint and wait — do not auto-advance even if user says "continue" without acknowledging them. Ask: "There are {N} unresolved items above. Confirm you want to continue anyway, or address them first?"

### Phase 5 — Advance to Next Story

After "continue":

1. Query for the next incomplete story in the epic:
   ```bash
   gh issue list --milestone "{milestone_title}" --state open \
     --json number,title,labels --jq 'sort_by(.number) | .[0]'
   ```
   Fall back to scanning `docs/epics.md` for the next story with `Status: not started` or no file.

2. If a next story exists in the **same epic**: announce "Moving to {epic}.{next_story}: {title}." and return to **Phase 1**.

3. If no stories remain in the current epic: proceed to **Phase 5b — Epic Boundary Gate**.

### Phase 5b — Epic Boundary Gate

All stories in the current epic are done. Before starting a new epic, present:

```
─────────────────────────────────────────────
EPIC {N} COMPLETE — {X} stories done
─────────────────────────────────────────────
All stories in Epic {N} are implemented and reviewed.

What would you like to do next?
  • "retro"     — run a retrospective for Epic {N} before continuing
  • "continue"  — skip retrospective and start Epic {N+1}
  • "stop"      — end the flywheel here
─────────────────────────────────────────────
```

**Wait for user response.**

- **"retro"**: Execute `skills/retrospective/skill.md` for the completed epic. After it finishes, prompt again:
  ```
  Retrospective complete. Ready to start Epic {N+1}: {title}.
    • "continue" — start the flywheel on Epic {N+1}
    • "stop"     — end the flywheel here
  ```
  Wait for response, then act accordingly.
- **"continue"**: Identify the first incomplete story in the next epic and return to **Phase 1** with that story.
- **"stop"**: Exit gracefully (see **User-Stopped**).

---

## Exit Conditions

### Epic Complete

All epics and stories are done (no remaining open issues or stories in `docs/epics.md`):

```
─────────────────────────────────────────────
ALL EPICS COMPLETE
─────────────────────────────────────────────
Every story across all epics is implemented and reviewed.

Next steps:
  • Run /retrospective if you haven't already
  • Check /status for overall project state
─────────────────────────────────────────────
```

### User-Stopped

When user types "stop":

```
Flywheel stopped after {epic}.{story}. {X} stories remain in Epic {N}.
Resume anytime with: /story-flywheel {epic}.{next_story}
```

### HALT (dev-story blocker)

Reported inline as described in Phase 2. Flywheel does not auto-resume.

---

## Resuming Mid-Epic

`/story-flywheel` with no argument will detect the in-flight story:
- If a story has `Status: in-progress` or GitHub label `in-progress`: resume at Phase 2 (dev-story).
- If a story has `Status: review` or GitHub label `review`: resume at Phase 3 (code-review), then proceed to Phase 4 (checkpoint).
- If no in-flight story: start from the first incomplete story.

---

## Notes

- **Toward hands-off runs.** Subagent delegation already collapses the human touch-points to three: the Phase-1 clarification surfacing, the Phase-4 checkpoint, and the epic-boundary gate. To go further, the user may pre-authorize **auto-pilot**: at the start they say "auto-continue on clean stories" — then for any story whose checkpoint has *no* `UNRESOLVED` items, a PASS rubric gate, and a green Build & Test Gate, the flywheel commits (if the user also pre-authorized commits) or pauses only to let the user commit, then advances without waiting for "continue". Any story with unresolved items, a FAIL gate, a red build, or a HALT **always** stops for the human regardless of auto-pilot. This is how the user gets "the app builds while I just steer at checkpoints" without losing the safety gates. Default remains: pause every checkpoint.
- The flywheel does not commit unless the user pre-authorizes it. You own the commit gate between stories.
- GitHub tracking is handled by the sub-skills (create-story, dev-story, code-review) — flywheel does not call tracking ops directly.
- If GitHub is unavailable, flywheel falls back to `docs/epics.md` Status fields for all story discovery.
- Deferred items are logged and scheduled by `skills/deferred/SKILL.md` (called via code-review). SCHEDULE tries SLOT-INTO-BACKLOG first — injecting the item as an AC on the best matching not-started backlog story — and only creates a new remediation story if no suitable slot exists. The flywheel surfaces deferred items in the Phase 4 checkpoint with their D-ID and the story they were slotted into or created as.
