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
| D-1 | {title} | {issue} | `{file}` | Story {epic}.{N} | {date} |
```

---

## LOG-AND-SCHEDULE

Input: `title`, `detail`, `source` (where issue found).
Called by: dev-story/code-review/correct-course/investigate/quick-dev when triaging defer findings.

Steps:
1. Get next ID from last row of `docs/deferred-items.md` (or D-1 if new).
2. Call **SCHEDULE** to add story to `docs/epics.md`.
3. Append row to `docs/deferred-items.md`.
4. In source file, mark `[x] [Defer]` with D-ID + story number.

Return: D-ID and story assigned.

---

## SCHEDULE

Input: `title`, `detail`, `source`, optionally `target_epic`.

Semantic epic matching: place issue in epic whose scope naturally contains this work (security→auth epic, UI→UI epic, perf→perf epic, etc.).

If no match: append to last incomplete epic (or create Epic R: Remediation if all complete).

Entry format (append to epic's stories):
```markdown
### Story {epic}.{N}: {title} *(remediation)*
**Origin:** D-{ID} — deferred from `{source}`
**Issue:** {detail}
**Status:** not started
```

Update epic story count. Execute **ENSURE-MILESTONE** + **CREATE-ISSUE** (skip if unavailable).

Return: story number and epic.

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
