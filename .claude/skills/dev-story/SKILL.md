---
name: dev-story
description: Implement a story from its story file. Use when the user says "dev story", "implement story", or "dev {story file path}".
---

# Dev Story Skill

**Goal:** Implement all tasks until ACs satisfied and DoD passes.

**Iron rule:** Only stop when: (a) all tasks done and DoD passes, (b) HALT condition, or (c) user says stop.

## Activation

1. Identify story: user path or first `Status: ready-for-dev` in `docs/epics/`. Stop if not found.
2. Read story file completely.
3. Read CLAUDE.md if exists (may override Dev Notes).
4. **If `docs/setup/swift/` exists** (Apple platform project): read the files relevant to this story's tasks before implementing:
   - Any story touching data models, services, or `@Observable`: read `docs/setup/swift/state-management.md`
   - Any story touching async loading, background work, or threading: read `docs/setup/swift/concurrency.md`
   - Any story adding new features, services, or project structure: read `docs/setup/swift/architecture.md`
   - Any story adding views or UI components: read `docs/setup/swift/ui-composition.md`
   - Any story adding tests: read `docs/setup/swift/testing.md`
   - Always read `docs/setup/swift/anti-patterns.md` if present — it governs what must not be written
   - If `docs/setup/swift/ipados-specific.md` exists and the story touches navigation, split view, drag-and-drop, pointer, keyboard, or multi-window: read it
   - If `docs/setup/swift/macos-specific.md` exists and the story touches menus, windows, toolbar, settings, tables, or file operations: read it
4b. **If `docs/setup/web/` exists** (web/SSG project): read the files relevant to this story's tasks before implementing:
   - Any story touching stylesheets, tokens, or layout: read `docs/setup/web/css-design-system.md`
   - Any story adding pages, forms, or content templates: read `docs/setup/web/accessibility-seo.md`
   - If `docs/setup/web/astro.md` exists and the story touches `.astro` files, collections, or images: read it
   - If `docs/setup/web/hugo.md` exists and the story touches `layouts/`, `content/`, or `assets/`: read it
   - Always read `docs/setup/web/anti-patterns.md` if present — it governs what must not be written
4c. **Design contract** (UI stories): if the story has a `### Design Contract` in Dev Notes, it is the design source of truth — use its tokens, states, and reuse list; do not read `docs/ux/` again. If the story changes user-visible UI but has **no** Design Contract and `docs/ux/DESIGN.md` exists: read DESIGN.md frontmatter and the relevant EXPERIENCE.md sections before implementing (and note the gap in Completion Notes so `/create-story` improves next time).
5. Execute **TRANSITION** with `new_label: in-progress` (skip if unavailable).
6. Confirm: "Implementing {epic}.{story}: {title}. Starting..."

## Execution

For each task in order:
1. Read task. Understand file, action, outcome.
2. Implement.
3. Check box: `[ ]` → `[x]`.
4. If problem found, log in Debug Log; continue.

Don't ask for clarification (use Dev Notes; log ambiguous calls in Completion Notes).

After major task groups, suggest `/compact` if context heavy. Don't block; continue.

## HALT Conditions
Stop if:
- Required file/dependency missing and can't infer
- AC contradictory or impossible
- Task requires out-of-scope changes risking breakage

## Story File Updates

Modify only:
- Tasks/Subtasks — check off `[ ]` → `[x]` as each task completes
- Acceptance Criteria — check off `[ ]` → `[x]` as each AC is satisfied; do this during implementation, not after
- Architecture Compliance Checklist (if present in Dev Notes) — check off each item before marking done
- Debug Log — log issues
- Completion Notes — key decisions
- File List — files created/modified/deleted
- Change Log — one-line per session
- Status — to `review` when done

Don't modify: User Story statement, Dev Notes prose, References.

## Definition of Done

Before review, verify all items in `checklist.md` pass. Fix any failures first.

## On Completion

When tasks done and DoD passes:

1. **Design verification (UI stories):** if the story changed user-visible UI, execute **VERIFY** from `skills/design-verify/SKILL.md` — render the changed surfaces (simulator or dev server + screenshots), compare against the Design Contract, and write results to `### Design Verification` in the story file. Mismatches feed into the inline review triage below as findings. If no rendering tooling is available, record the manual checklist and continue. Skip entirely for stories with no user-visible surface.
2. Run code-review inline (don't stop). Continue directly to Code Review below.

---

## Inline Code Review

The diff is uncommitted changes. Story file is loaded. Go straight to three passes.

### Three Passes

**Pass A — Blind Correctness:** Logic errors, null dereferences, unchecked returns, injection/auth/data exposure, races, leaks, error handling.

**Pass B — Edge Case & Regression:** Boundary checks, error paths, callers outside diff, unchecked assumptions.

**Pass C — Acceptance Audit:** Unimplemented/partial ACs, AC contradictions, ignored constraints, files touched/not touched.

**Pass D — Security (conditional):** If Dev Notes has `Security Sensitivity:`, run matching categories from `skills/security-review/skill.md`. Skip if blank.

**Pass E — Design Compliance (conditional):** If the diff touches user-visible UI and a `### Design Contract` (or `docs/ux/DESIGN.md`) exists: hardcoded values where a token exists, missing required states (empty/loading/error), missing dark-mode pair, platform checklist violations (tap targets, Dynamic Type, semantic HTML, focus visibility), near-duplicate of an inventoried component. Include any unresolved `### Design Verification` findings. Skip for non-UI diffs.

### Triage

Tag each finding:
- `decision-needed` — ambiguous; fix needs user input
- `patch` — clear bug; unambiguous fix
- `defer` — pre-existing, not from this diff
- `dismiss` — noise or false positive

Merge duplicates. Drop `dismiss`.

### Record Findings

Write non-dismissed findings to `### Review Findings` subsection:
- `- [ ] [Decision] {title} — {detail}`
- `- [ ] [Patch] {title} [{file}:{line}]`
- `- [ ] [Defer] {title} — pre-existing`

### Resolve and Patch

- Zero findings: skip to Wrap Up
- `decision-needed`: list all, wait for answers, record decisions, convert to patch/defer/dismiss
- Auto-patch all `patch` (including resolved decisions). Mark `[x]`.
- If patch can't auto-apply: surface explicitly, leave `[ ]`

### Pull Deferred Items Forward

After patches, check for `[ ] [Defer]` items in story file. If found, execute **RESOLVE** from `skills/deferred/skill.md`. Surfaces immediately with fresh context.

### Wrap Up

**All resolved:**
1. Status = `done`
2. **CLOSE-ISSUE** (skip if unavailable)
3. Report: "{epic}.{story} complete. {P} patches, {D} decisions, {W} deferred."

**Unresolved patches remain:**
1. Status = `in-progress`
2. **TRANSITION** to `in-progress` (skip if unavailable)
3. Report which items need attention
