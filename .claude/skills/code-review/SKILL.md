---
name: code-review
description: Review code changes adversarially. Use when the user says "review", "code review", or "review story {X}". Also embedded automatically at the end of /dev-story — see that skill for the inline variant.
---

# Code Review Skill

**Goal:** Find real bugs, missing behavior, AC violations. Assume problems exist — your job is to find them. Zero findings requires explicit justification ("re-analyzed, clean because…"), not silence.

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
- **If `docs/setup/swift/` exists** (Apple platform project): read `docs/setup/swift/anti-patterns.md` and `docs/setup/swift/state-management.md` before beginning passes — use them as the rejection criteria for Pass A and Pass C. Also read `docs/setup/swift/ipados-specific.md` if present and the diff touches navigation, split view, or multi-window code; read `docs/setup/swift/macos-specific.md` if present and the diff touches menus, windows, settings, or toolbar code.
- **If `docs/setup/web/` exists** (web/SSG project) and the diff touches templates, markup, or styles: read `docs/setup/web/anti-patterns.md` and `docs/setup/web/css-design-system.md` — use them as rejection criteria.
- **If the diff touches user-visible UI** and `docs/ux/DESIGN.md` exists: read its frontmatter token block (and the story's `### Design Contract` if present) — required input for Pass E.
- Confirm: "Reviewing {N} files, {+/-lines}. Story context: {yes/no}."

## Step 3 — Five Review Passes

Work each pass independently. Look for what's *missing* (absent behavior, unhandled path) as hard as what's *wrong*.

**Pass A: Blind Correctness** — read the diff as if you wrote none of it
- Logic errors: off-by-one, wrong operator, inverted condition, stale state
- Null/zero/empty dereference: unchecked optional, missing guard before index
- Unchecked return values: ignored errors, discarded Results/Optionals
- Resource leaks: unclosed file handles, connections, or goroutines without cleanup
- Concurrency: shared mutable state without synchronization, TOCTOU races
- Error handling: swallowed errors, generic catch blocks that hide root cause
- Type coercion / implicit conversion producing unexpected values
- Dead code or unreachable branches that indicate a logic mistake

**Pass B: Security & Data** — adversarial user mindset
- Injection: SQL/command/HTML built with string concatenation from user input
- Auth: missing authentication check, missing authorization/ownership check (IDOR)
- Secrets: hardcoded keys, tokens, passwords in source or committed config
- Data exposure: API response leaks fields the caller shouldn't see; PII in logs
- Input validation: missing size/type/range checks at trust boundaries
- Session/token: insecure storage (localStorage), missing expiry, no rotation
- Rate limiting absent on auth, registration, reset, or expensive endpoints

**Pass C: Edge Case & Regression** — break it with inputs
- Boundary values: empty collection, zero, negative, max int, nil/null
- Missing error paths: what happens when the external call fails, returns empty, or times out?
- Callers outside the diff: does this change break existing call sites?
- Unchecked assumptions baked into the new code (e.g., "list is always non-empty")
- Regression: does the change touch behavior relied on elsewhere?

**Pass D: Acceptance Audit** (only if story loaded)
- Each AC: implemented? fully? or only the happy path?
- ACs that contradict each other or the architecture
- Constraints in Dev Notes that were ignored
- Files the story said would be touched that weren't (missing implementation)

**Pass E: Design Compliance** (only if the diff touches user-visible UI and `docs/ux/DESIGN.md` or a `### Design Contract` exists)
- Hardcoded colors/spacing/type values where a DESIGN.md token exists (near-miss hex counts)
- Required states from EXPERIENCE.md missing: empty, loading, error, offline
- Dark mode: load-bearing surfaces missing the second appearance
- Platform checklist: Apple — tap targets, Dynamic Type, safe areas, SF Symbols; web — semantic elements, focus visibility, `alt`, heading hierarchy, off-token `!important`/inline styles
- New component that near-duplicates one in `docs/ux/components-built.md`
- Unresolved findings in the story's `### Design Verification` section
- **Dark patterns** (check the diff against EXPERIENCE.md's `## Engagement & Persuasion`, if present): pre-checked paid or consent opt-ins; smart defaults that pre-select the higher-cost/higher-commitment choice; fake or endowed progress indicators; countdown/urgency with no real deadline; guilt-decline (confirmshaming) copy; decoy pricing. Flag any lever in the diff that isn't backed by an honest entry in that section — shipping user-hostile behavior is HIGH severity (it erodes trust and is a support/churn liability, not just a style nit).

## Step 4 — Triage and Severity

For each finding assign both a category and severity:

**Category:**
- `decision-needed` — ambiguous; needs user input before a fix is possible
- `patch` — clear bug; unambiguous fix exists
- `defer` — pre-existing issue not introduced by this diff
- `dismiss` — confirmed false positive (state reason)

**Severity** (for `patch` and `decision-needed`):
- `HIGH` — data loss, auth bypass, secret exposure, injection, crash in main path
- `MEDIUM` — incorrect behavior under reachable conditions, missing error handling, IDOR
- `LOW` — edge case with low probability, best-practice gap, missing guard on unlikely path

Merge duplicates. Drop `dismiss`. If zero remain: write `Clean review — no patches or deferred items.` and justify briefly why each pass came up empty.

## Step 5 — Report and Act

**Write findings:** If story loaded, write to `### Review Findings`:
- If clean review: write `Clean review — no patches or deferred items.` plus one-sentence justification per pass.
- Otherwise, order by severity (HIGH first), then category:
  - `- [ ] [HIGH/MEDIUM/LOW] [Decision] {title} — {detail}`
  - `- [ ] [HIGH/MEDIUM/LOW] [Patch] {title} [{file}:{line}]`
  - `- [ ] [Defer] {title} — pre-existing ({file}:{line})`

**Summary:** "Review complete. {D} decision, {P} patches, {W} deferred."

**Resolve decisions:** All at once, wait for answers, record, convert to patch/defer/dismiss.

**Auto-patch:** Apply immediately, mark `[x]`. If can't auto-apply, leave `[ ]`.

**Verify green:** If any patch changed code and a toolchain is present, **run a real build + test** before marking the review done (`xcodebuild … build test` / `swift build && swift test` / `npm run build && npm test` / documented command). A patch is only resolved once the toolchain confirms it compiles and tests stay green — never close a review on a fix verified by reading alone. If red, fix and re-run, or leave the finding `[ ]` and set Status `in-progress`. Skip only on a clean review or when no toolchain exists (state which). If `docs/evals/` exists, also execute **RUN** from `skills/evals/SKILL.md` for the story's epic — a failing eval is a regression and blocks closing just like a red build.

**Eval Scorecard:** Emit a structured pass/fail line — this is just turning the passes you already ran into scored output, **no extra model calls**. Execute **SCORE** from `skills/evals/SKILL.md`: one verdict per applicable dimension and an overall gate. Append to `### Review Findings`:

```
RUBRIC: correctness PASS · edge-cases PASS · ac-coverage PASS · design PASS · security n/a → GATE PASS
```

A dimension is FAIL if any unresolved `[ ]` finding maps to it; GATE is PASS only when every applicable dimension is PASS. The gate feeds the flywheel checkpoint and the ledger.

**Pull deferred forward:** If any `[ ] [Defer]`, execute **LOG-AND-SCHEDULE** from `skills/deferred/skill.md` for each deferred item (title = finding title, detail = finding detail, source = file:line).

**Update epic context:** Before updating status, check for discoveries made during review or fix application that future stories/epics should know about. Look for:
- Constraints or invariants uncovered while fixing bugs
- Schema, API, or integration details that differed from assumptions
- Patterns established or broken during patches
- Any "we learned X the hard way" that isn't obvious from the code

If a story file was loaded, identify its epic (e.g., `epic-2` from `epic-2-story-3.md`). Check whether `docs/epics/epic-<n>-context.md` exists. If discoveries exist, append them under a `## Story {id} Learnings` heading. If no discoveries worth capturing, skip silently. (These project-canonical learnings are promoted into `docs/architecture.md` at the epic boundary by `/epic-flywheel`.)

**Flag guidance drift:** If, while using `docs/setup/swift/` or `docs/setup/web/` as rejection criteria (Step 2), you found that the *guidance itself* is wrong, stale, or contradicted by what the codebase consistently and intentionally does (not a one-off bug — that's a finding), execute **DRIFT** from `skills/docs-sync/SKILL.md` with the contradiction. It emits a `/refresh-swift|web` advisory and never mutates `docs/setup/*` (external-sourced canon). Skip silently if the guidance held.

**Update component inventory:** If the diff introduced a new reusable UI component (a view/element designed to be used in more than one place), append a row to `docs/ux/components-built.md` — create the file with this header if missing:

```markdown
# Components Built
*Auto-maintained by /code-review. /create-story injects this into UI stories — reuse these, never create near-duplicates.*

| Component | File | Purpose | Variants/Props |
|---|---|---|---|
```

One-off layout subviews don't qualify; only components future stories should reuse. Skip silently if no new reusable component shipped.

**Ledger:** If `docs/metrics/` exists, append one `code-review` line to `docs/metrics/flywheel-ledger.jsonl` (single shell redirect — do not read the file into context): `{ts, story, phase:"code-review", model, build_test, evals:"P/T", findings:{patched,decisions,deferred}, rubric_gate}`.

**Update status** (in the YAML frontmatter — the source of truth; never as a `**Status:**` body line):
- All resolved: `status: done` → **CLOSE-ISSUE**
- Unresolved patches: `status: in-progress` → **TRANSITION**
