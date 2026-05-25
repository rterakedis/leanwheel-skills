---
name: code-review
description: Review code changes adversarially. Use when the user says "review", "code review", or "review story {X}". Also embedded automatically at the end of /dev-story — see that skill for the inline variant.
---

# Code Review Skill

**Goal:** Find real bugs, missing behavior, AC violations. No noise.

**Note:** Inline in `/dev-story` skips Steps 1–2 (context already loaded). This is for PRs/branches/commits outside the flywheel.

## Step 1 — Find the Diff

Check in order (stop when found):
1. Explicit argument (PR, branch, commit, story file)?
2. Story with `Status: review` in `docs/epics/`?
3. Current branch not main/master?
4. Ask: "What do you want to review?"

If empty diff: stop. If >3000 lines: warn, offer to chunk by file.

## Step 2 — Load Context

- If story file identified: read fully.
- Read CLAUDE.md if exists.
- Confirm: "Reviewing {N} files, {+/-lines}. Story context: {yes/no}."

## Step 3 — Three Review Passes

**Pass A: Blind Correctness**
Logic errors, null dereference, unchecked returns, injection/auth/data exposure, races, leaks, error handling.

**Pass B: Edge Case & Regression**
Boundary checks, missing error paths, callers outside diff, unchecked assumptions.

**Pass C: Acceptance Audit** (if story loaded)
Unimplemented/partial ACs, AC contradictions, ignored constraints, files touched/untouched.

## Step 4 — Triage

For each finding:
- `decision-needed` — ambiguous; needs user input
- `patch` — clear bug; unambiguous fix
- `defer` — pre-existing, not from this diff
- `dismiss` — noise or false positive

Merge duplicates. Drop `dismiss`. If zero remain: clean review.

## Step 5 — Report and Act

**Write findings:** If story loaded, write to `### Review Findings`:
- `- [ ] [Decision] {title} — {detail}`
- `- [ ] [Patch] {title} [{file}:{line}]`
- `- [ ] [Defer] {title} — pre-existing`

**Summary:** "Review complete. {D} decision, {P} patches, {W} deferred."

**Resolve decisions:** All at once, wait for answers, record, convert to patch/defer/dismiss.

**Auto-patch:** Apply immediately, mark `[x]`. If can't auto-apply, leave `[ ]`.

**Pull deferred forward:** If any `[ ] [Defer]`, execute **RESOLVE** from `skills/deferred/skill.md`.

**Update status:**
- All resolved: Status `done` → **CLOSE-ISSUE**
- Unresolved patches: Status `in-progress` → **TRANSITION**
