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

**Testability foundation story (Apple app projects):** if the architecture targets iOS/iPadOS/macOS, Epic 1 must include an early story (immediately after project scaffold, before the first feature story) that ships the foundation from `docs/setup/swift/testability.md`: the `SeedScenario` registry (empty/firstRun/typical/heavy/edge), the launch-argument contract (`--seed`/`--uitest`/`--reset` with in-memory store isolation), the accessibility-identifier convention, and one XCUITest smoke target with 2–4 tests. Every later story then *keeps* seeds and identifiers current instead of retrofitting them — this story is what makes automated testing cheap for the rest of the project.

**Cross-epic runtime dependency scan (do after drafting all epics, before writing):**

For every epic, ask: does any story in this epic require a runtime artifact — migration, seed data, table, endpoint — that lives in a *later* epic to be end-to-end testable or operationally complete?

Common patterns to check:
- A seed/bootstrap story (e.g. "create admin user") that only becomes useful after a later epic provides the permission model
- A data model story that references a table introduced in a later epic
- An auth epic whose "first login" flow depends on tenant data only created in a later onboarding epic

For each identified cross-epic dependency:
- Add a note to the *earlier* epic's implementation order: "Operationally complete only after Story X-Y ships"
- Add a note to the *later* epic's relevant story: "Unblocks Story A-B from being fully testable"
- If the dependency is a blocker (earlier epic cannot be validated without it), consider reordering epics or splitting the blocking story out into the earlier epic

## Phase 3 — FR Coverage Check

Verify: every FR in ≥1 story, no gaps or overlaps. Show coverage table. Resolve gaps before writing.

## Phase 4 — Write and Sync

1. Write `docs/epics.md` using template.
2. Create GitHub milestones via **ENSURE-MILESTONE** for each epic (skip if GitHub unavailable).
3. If stories are present in `docs/epics.md`: create one GitHub issue per story via **CREATE-ISSUE** with `initial_label: backlog`, attaching each issue to its epic's milestone. Use the story's user story statement + ACs as the issue body. Skip write-back (no story file exists yet).
4. Report: "{E} epics, {S} stories written, {N} GitHub issues created. Next: `/create-story`."
