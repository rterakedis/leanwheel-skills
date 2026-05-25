---
name: epics
description: Break the PRD into epics and stories, write docs/epics.md, and create GitHub milestones. Use when the user says "create epics", "break down the PRD", or "plan stories".
---

# Epics Skill

**Goal:** Decompose PRD into epics and stories; produce `docs/epics.md` and GitHub milestones.

**Role:** Organize around user value, not tech layers.

## Activation

1. Read `docs/prd.md` (required; stop if missing).
2. Read `docs/architecture.md` (required; stop if missing).
3. Check for `docs/epics.md` (may be update run).
4. Confirm: "Read PRD and architecture. Ready to design epics."

## Phase 1 — Design Epic List

Principles:
- User value (not tech layers); independently shippable; natural progression
- 3–6 stories per epic; minimize file churn

Process:
1. Group PRD FRs by user capability
2. Draft: title + one-sentence goal per epic
3. Confirm with user: standalone value? right FRs? correct sequence?
4. Iterate until approved

## Phase 2 — Generate Stories

Rules:
- One dev session per story; split if too large
- Sequential dependencies only (N.3 depends on N.1, N.2 only)
- Create only what needed (no speculation)
- 2–4 testable ACs per story
- Track FR coverage explicitly

For each epic:
1. List FRs it covers
2. Propose breakdown: title + one-liner + FRs satisfied
3. Get user confirmation, adjust
4. Write full entries using template

## Phase 3 — FR Coverage Check

Verify: every FR in ≥1 story, no gaps or overlaps. Show coverage table. Resolve gaps before writing.

## Phase 4 — Write and Sync

1. Write `docs/epics.md` using template.
2. Create GitHub milestones via **ENSURE-MILESTONE** for each epic (skip if GitHub unavailable).
3. If stories are present in `docs/epics.md`: create one GitHub issue per story via **CREATE-ISSUE** with `initial_label: backlog`, attaching each issue to its epic's milestone. Use the story's user story statement + ACs as the issue body. Skip write-back (no story file exists yet).
4. Report: "{E} epics, {S} stories written, {N} GitHub issues created. Next: `/create-story`."
