---
name: deferred
description: Composable deferred-item operations. Called by other skills when a finding is deferred. Directly invocable as /deferred to view the current log.
---

# Deferred Items (Composable)

Composable operations for deferring findings → auto-scheduling as stories. Other skills call LOG-AND-SCHEDULE; user never manages queue.

Directly invocable: `/deferred` — show log and linked story status.

---

## `docs/deferred-items.md` — the log

Append-only single source of truth. Format:

```markdown
| ID | Title | Detail | Source | Scheduled As | Date |
|----|-------|--------|--------|--------------|------|
| D-1 | {title} | {issue} | `{file}` | Story {epic}.{N} (slotted as AC) | {date} |
| D-2 | {title} | {issue} | `{file}` | Story {epic}.{N} (new remediation) | {date} |
```

---

## LOG-AND-SCHEDULE

Input: `title`, `detail`, `source` (where issue found).
Called by: dev-story/code-review/correct-course/investigate/quick-dev when triaging defer findings.

**Named trigger — observed test flake or hang.** A test suite that flakes or hangs is logged here the moment it is observed, never waved off as "passes in isolation." A festering hang blocks the next epic-boundary gate and masquerades as agent failures.

**Gate — surface a decision instead of logging it.** Before completing the steps below: if the item you are about to write contains "decide: (a)/(b)/(c)", "needs a product decision", or similar, you have already done the analysis and the only thing being deferred is *asking*. Ask in that turn instead. A decision needs the owner when **any** of: both choices destroy or strand something the user created; the options differ in what they promise the user (not just how it's built); the answer depends on product intent not in the repo; or it is expensive to reverse once users build habits on it. Everything else — implementation shape, equally-correct APIs, anything strictly better on every axis — just decide and mention it. This is the biggest cause of deferred-log bloat.

**Gate — reject anything that meets the `[Fix-Now]` bar.** Before logging, test the item against `code-review` → Step 4's `fix-now` ceiling (≤ ~10 lines in one file adjacent to the diff under review, provably safe, no new dependency/schema/public-API/user-visible-copy change, one commit line). If it clears all four, do **not** log it: return `fix-now — not logged` and tell the caller to apply it in this pass. The log's value is proportional to its signal, and a two-line fix sitting in it costs more to schedule than to make.

Steps:
1. Get next ID from last row of `docs/deferred-items.md` (or D-1 if new).
2. Call **SCHEDULE** (which tries **SLOT-INTO-BACKLOG** first, falls back to new remediation story).
3. Append row to `docs/deferred-items.md`, noting "slotted as AC" or "new remediation" in Scheduled As.
4. In source file, mark `[x] [Defer]` with D-ID + story number.

Return: D-ID and story assigned (with slot/new distinction).

---

## SCHEDULE

Input: `title`, `detail`, `source`, `d_id`, optionally `target_epic`.

**Step 1 — try SLOT-INTO-BACKLOG first.** If a suitable not-started story exists, inject there instead of creating a new one. Return early if slotted.

**Step 2 — fallback: new remediation story.** Semantic epic matching: place in the epic whose scope naturally contains this work (security→auth epic, UI→UI epic, perf→perf epic, etc.). If no match: append to last incomplete epic (or create Epic R: Remediation if all complete).

**Never target a closed epic.** An epic carrying a `<!-- retro: epic {N} -->` stamp — or collapsed to a summary table by `epic-archive` CONDENSE — is shipped: its retro is written and its milestone closed. Semantic matching considers **open epics only**; if the best semantic match is closed, fall through to the last incomplete epic (or Epic R). Same immutability rule `harvest-findings` applies to done stories.

New story entry format (append to epic's stories):
```markdown
### Story {epic}.{N}: {title} *(remediation)*
**Origin:** D-{ID} — deferred from `{source}`
**Issue:** {detail}
**Status:** not started
```

Update epic story count. Execute **ENSURE-MILESTONE** + **CREATE-ISSUE** (skip if unavailable).

Return: story number and epic, and whether slotted or new.

---

## SLOT-INTO-BACKLOG

Input: `title`, `detail`, `source`, `d_id`.

Find the best existing backlog story to absorb the deferred item as an AC:

1. Read `docs/epics.md`. Collect all stories with `Status: not started`.
2. Score each candidate: +2 if the story's epic/title domain matches the finding (security, UI, perf, data, auth, etc.); +1 if the story is in the next unstarted epic; 0 otherwise. Pick the highest-scoring candidate. If tie, prefer the earliest story number.
3. If a candidate with score ≥ 1 exists:
   - Open the story file (if it exists) or the epics entry.
   - Append under its `## Acceptance Criteria` section (or add the section if absent):
     ```markdown
     - [ ] [D-{d_id}] {title}: {detail} *(slotted from deferred — origin: `{source}`)*
     ```
   - If the story has a GitHub issue open, add a comment: "Deferred item D-{d_id} slotted as AC: {title}"
   - Return: slotted into Story {epic}.{N} — SCHEDULE skips Step 2.
4. If no candidate scores ≥ 1: return "no slot found" → SCHEDULE continues to Step 2.

---

## Callers of LOG-AND-SCHEDULE

dev-story: triaged `defer` findings → title, detail, story path.
code-review: triaged `defer` findings → title, detail, story/branch.
correct-course: `new-story` impacts on done work → title, what was wrong, story path.
investigate: handoff recommends story → root cause, summary, case path.
quick-dev: deferred findings → title, detail, spec path.

---

## VIEW (`/deferred`)

Read `docs/deferred-items.md`. If empty: "No deferred items." Otherwise: display table + note which scheduled stories are not started vs. completed/removed.
