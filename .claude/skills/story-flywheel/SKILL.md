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

4. **Determine model-routing mode.** Set `swift_project = true` if `docs/setup/swift/` exists OR an `.xcodeproj` / `.xcworkspace` / `Package.swift` is present in the repo; otherwise `false`.
   - **`swift_project = true`:** model-switch gates are **on** (see Model Routing). Tell the user up front:
     > This is an Apple/Swift project. Swift can't be reliably verified by reading, so I'll pause before each phase to have you switch models for token efficiency: **Sonnet** for story creation & review, **Opus (medium)** for implementation. Two switches per story. Set your model to **Sonnet** now before I create the first story.
     Wait for the user to confirm before Phase 1.
   - **`swift_project = false`:** model-switch gates are **off** — the flywheel runs fully automated as before. Note once: "Non-Swift project — running fully automated; Sonnet/Haiku handles this surface well. Switch up to Opus yourself only if a specific story proves stubborn." Do not pause for model changes.

---

## Model Routing (Apple/Swift projects only)

Active only when `swift_project = true`. The model can't change its own model — these are **hard stops** that wait for the user to switch it in the Claude Code UI (`/model`), then confirm. Switching preserves session context, so the loop continues seamlessly after each switch.

Per-story model plan (2 switches per story):

| Phase | Model | Reasoning | Why |
|---|---|---|---|
| 1 — Create Story | **Sonnet** | medium | Story authoring doesn't need Opus; Sonnet is cost-efficient here. |
| 2 — Dev Story | **Opus** | medium (high for concurrency / complex SwiftUI state) | Highest per-attempt Swift accuracy — fewest build-gate iterations, where the tokens are actually saved. |
| 3 — Code Review | **Sonnet** | high | Adversarial reading; the Build & Test Gate is the correctness backstop, not the model. |

A **MODEL SWITCH GATE** looks like:

```
─────────────────────────────────────────────
MODEL SWITCH — before {phase}
Set your model to: {model} ({reasoning} reasoning)
  • Run /model and select it
  • Type "ready" when switched
─────────────────────────────────────────────
```

Wait for "ready" (or equivalent). If the user says to skip switching ("just keep going", "stay on current"), honor it for the rest of the run and stop prompting — they've opted out of the token optimization. Skip a gate when the target model already matches the last one set (e.g. Phase 1 of the next story is already Sonnet after Phase 3).

---

## The Loop

Repeat until the epic is complete (see **Exit Conditions**):

### Phase 1 — Create Story

**If `swift_project`:** issue a MODEL SWITCH GATE for **Sonnet (medium)** and wait for "ready" — unless Sonnet was already the last model set (e.g. carried over from the previous story's Phase 3). See Model Routing.

Execute `skills/create-story/skill.md` for the current story.

- Pass the story identifier (epic.story) so create-story skips the identification step.
- Wait for the story file to be written and GitHub issue to be updated.
- Do not proceed to Phase 2 until create-story completes and returns the story file path.

### Phase 2 — Dev Story

**If `swift_project`:** issue a MODEL SWITCH GATE for **Opus (medium** — high reasoning if the story touches concurrency, actor isolation, or complex SwiftUI state**)** and wait for "ready" before executing. See Model Routing.

Execute `skills/dev-story/skill.md` with the story file path from Phase 1.

- Dev story runs implementation only: all tasks, DoD check, and story file updates.
- Do not proceed to Phase 3 until dev-story reports all tasks complete and DoD passes.

**On HALT:** Stop the flywheel. Report: "Flywheel paused — dev-story halted on {epic}.{story}: {reason}. Resolve the blocker and resume with `/story-flywheel {epic}.{story}`."

### Phase 3 — Code Review

**If `swift_project`:** issue a MODEL SWITCH GATE for **Sonnet (high)** and wait for "ready" before executing. The Build & Test Gate (re-run after patches) is the correctness backstop, so review does not need Opus. See Model Routing.

Execute `skills/code-review/skill.md` for the story completed in Phase 2.

- Pass the story file path so code-review loads it as context (skips Steps 1–2 auto-detection).
- Code review runs its three passes (Pass A: Blind Correctness, Pass B: Edge Cases, Pass C: AC Audit) plus Pass D if security-sensitive.
- When `decision-needed` findings surface, pause and wait for answers before continuing — these are the primary human input points during review.
- After decisions are resolved, auto-patch all `patch` findings. Log any `defer` findings via `skills/deferred/skill.md`.
- Wait for code-review to report completion before proceeding to Phase 4.

**On unresolvable patches:** Do not proceed to Phase 4. Leave story status `in-progress`, report which items need attention, and stop the flywheel. Resume with `/story-flywheel {epic}.{story}` after the issues are addressed.

### Phase 4 — Human Checkpoint

After code review completes, surface a consolidated checkpoint before any commit:

```
─────────────────────────────────────────────
STORY {epic}.{story} CHECKPOINT
─────────────────────────────────────────────
Status: code review complete

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

- The flywheel does not commit. You own the commit gate between stories.
- GitHub tracking is handled by the sub-skills (create-story, dev-story, code-review) — flywheel does not call tracking ops directly.
- If GitHub is unavailable, flywheel falls back to `docs/epics.md` Status fields for all story discovery.
- Deferred items are logged and scheduled by `skills/deferred/SKILL.md` (called via code-review). SCHEDULE tries SLOT-INTO-BACKLOG first — injecting the item as an AC on the best matching not-started backlog story — and only creates a new remediation story if no suitable slot exists. The flywheel surfaces deferred items in the Phase 4 checkpoint with their D-ID and the story they were slotted into or created as.
