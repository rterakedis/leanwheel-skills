---
name: correct-course
description: Manage mid-sprint changes and pull deferred items forward into the active workstream. Use when the user says "correct course", "change of plans", "we need to adjust", or "something came up".
---

# Correct Course Skill

**Goal:** When discovery/requirements/bugs break plan, update `docs/`, `docs/epics/`, and backlog coherently. Every impact: fix now, schedule as story, or defer with date/condition.

**Deferred problem:** `[Defer]` items in stories go nowhere. This skill pulls them forward and forces decisions.

## Activation

Ask: "What triggered this?"
1. Requirement changed
2. Bug in done work
3. Architecture wrong mid-implementation
4. External dependency changed
5. Scope creep
6. Other

Store trigger. Read `docs/epics.md` for status.

---

## Phase 1 — Triage the Trigger

Assess impact across: PRD (what/who), architecture (tech/patterns), epics (ACs/tasks/ordering), active story, done stories.

Note what changes and why for each affected artifact.

---

## Phase 2 — Classify Each Impact

`fix-in-place`: not implemented yet (ready-for-dev). Update docs/story directly.

`new-story`: done/review work OR large fix. Don't reopen done stories; schedule new story instead (keeps history clean).

`defer-explicitly`: real but out of scope. Must include: issue, why deferred, specific condition/date for revisit. No vague deferrals.

---

## Phase 3 — Pull Forward Deferred Items

Execute **SCAN** then **RESOLVE** from `skills/deferred/skill.md`. All open deferrals must be resolved (no orphaned items).

---

## Phase 4 — Execute Changes

**Fix-in-place:** Edit doc/story; add inline `<!-- corrected {date}: {reason} -->` if non-obvious.

**New stories:** Execute **SCHEDULE** from `skills/deferred/skill.md` (writes to epics.md + GitHub).

**Explicit deferrals:** Add to `## Deferred Items` in `docs/epics.md`: `- {date} — {issue} — Deferred until: {condition}. Trigger: {event}`.

---

## Phase 5 — Update Planning Docs

PRD changed: bump last-updated, one-line comment at section top.
Architecture changed: bump last-updated. If pattern changed, `touch docs/architecture.md` to invalidate caches.

---

## Phase 6 — Summary

Report: artifacts updated, new stories, deferred items, resolved deferrals, next action.

---

## When to Run This Skill vs. Others

Bug in **done** story: `/correct-course` (add remediation story forward).
Bug in **active** story: inline auto-patch.
Bug needs investigation: `/investigate` → `/correct-course`.
Small post-MVP: `/quick-dev`.
Requirements changed: `/correct-course` (may trigger `/prd` update).
