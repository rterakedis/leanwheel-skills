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
4. Execute **TRANSITION** with `new_label: in-progress` (skip if unavailable).
5. Confirm: "Implementing {epic}.{story}: {title}. Starting..."

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

When tasks done and DoD passes, run code-review inline (don't stop). Continue directly to Code Review below.

---

## Inline Code Review

The diff is uncommitted changes. Story file is loaded. Go straight to three passes.

### Three Passes

**Pass A — Blind Correctness:** Logic errors, null dereferences, unchecked returns, injection/auth/data exposure, races, leaks, error handling.

**Pass B — Edge Case & Regression:** Boundary checks, error paths, callers outside diff, unchecked assumptions.

**Pass C — Acceptance Audit:** Unimplemented/partial ACs, AC contradictions, ignored constraints, files touched/not touched.

**Pass D — Security (conditional):** If Dev Notes has `Security Sensitivity:`, run matching categories from `skills/security-review/skill.md`. Skip if blank.

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
