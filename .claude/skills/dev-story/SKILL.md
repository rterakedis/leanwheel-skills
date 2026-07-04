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

**Keep files maintainable as you go.** If a file you create or touch crosses the file-size / decomposition target in the routed guidance (`docs/setup/swift/ui-composition.md` or `docs/setup/web/`), decompose it **as part of the task** — don't defer it. Split along responsibility seams (Swift: `extension TypeName {}` files for members, named `private struct` sub-views for layout), never by mechanical line-cutting, and never by giving a sub-view its own data access. A 280-line file with one cohesive job is fine; a smaller file doing three jobs is not — cohesion decides the cut.

After major task groups, suggest `/compact` if context heavy. Don't block; continue.

## HALT Conditions
Stop if:
- Required file/dependency missing and can't infer
- AC contradictory or impossible
- Task requires out-of-scope changes risking breakage
- **Build or test suite cannot be made green** after a reasonable number of fix attempts (see Build & Test Gate). Do not mark the story `review` over a red build — report the failing output and HALT.

## Story File Updates

Modify only:
- Tasks/Subtasks — check off `[ ]` → `[x]` as each task completes
- Acceptance Criteria — check off `[ ]` → `[x]` as each AC is satisfied; do this during implementation, not after
- Architecture Compliance Checklist (if present in Dev Notes) — check off each item before marking done
- Invariant Verification (stateful stories) — record evidence per Behavior Contract invariant on completion
- Debug Log — log issues
- Completion Notes — key decisions
- File List — files created/modified/deleted
- Change Log — one-line per session
- Status — set `status: review` in the **YAML frontmatter** when done (frontmatter is the source of truth; do not write a `**Status:**` body line)

Don't modify: User Story statement, Dev Notes prose, References.

## Definition of Done

Before review, verify all items in `checklist.md` pass. Fix any failures first.

## Build & Test Gate

**Verification is by running, not by reading.** Static reasoning is not a substitute for the toolchain — especially for Swift, where result builders, macros (`@Observable`/`@Model`), actor isolation, and `some View` produce errors that cannot be reliably predicted by reading. Before the story can leave `in-progress`, the project must **compile clean and its tests must pass this session** — verified by actually invoking the toolchain, not by inspection.

1. Detect the toolchain and run a real build + test:
   - **Apple / Swift** (`docs/setup/swift/` exists, or an `.xcodeproj`/`Package.swift` is present): mandatory.
     ```bash
     # Xcode project/workspace
     xcodebuild -scheme {scheme} -destination 'platform=iOS Simulator,name=iPhone 16' build test
     # or SwiftPM
     swift build && swift test
     ```
   - **Web / SSG** (`package.json` present): run the project's build + test scripts (e.g. `npm run build && npm test`, or the lint/typecheck script if no tests).
   - **Other toolchains:** run the project's documented build + test command.
   - **No toolchain detected:** record a `Build & Test Gate: manual-required` note in the Debug Log with the exact command a human should run, and continue. Never fake a green result.
2. **Red build or failing test = not done.** Read the compiler/test output, fix the cause, and re-run. Loop until green. Do not patch the story file to `review` over a failure. If it cannot be made green after a reasonable number of attempts, **HALT** (see HALT Conditions).
3. **Run the cumulative eval set.** If `docs/evals/` exists, execute **RUN** from `skills/evals/SKILL.md` for this story's epic (zero-token: it just runs the accumulated `type: command` cases). A failing case is a **regression** of an earlier story — treat it exactly like a red build: fix and re-run, or HALT. This is what makes the regression net *cumulative* across stories, not just per-story.
4. **Update the eval set.** If `docs/evals/` exists and this story added tests that cover an AC or invariant, execute **BUILD** from `skills/evals/SKILL.md` to append (or flip `enabled: true` on) the corresponding `type: command` cases, so the next story inherits them.
5. Record the result in the Debug Log: the command run and `build+test green` (or the manual-required note), plus `evals: P/T`. This is the executable regression net that prevents a later story from silently reverting a prior fix — it only works if it actually runs every story.

## On Completion

When tasks done, DoD passes, **and the Build & Test Gate is green** (or manual-required is recorded):

1. **Invariant verification (stateful stories):** if the story's `### Behavior Contract` lists invariants, verify each one holds in the built code with **evidence** — a test that exercises it, or a cited assertion/guard in the source (`file:line`). Record results under `### Invariant Verification` in the story file: each invariant as `- [x] {invariant} — {test name | file:line}` or `- [ ] {invariant} — UNVERIFIED: {why}`. An invariant with no test and no enforcing code is **not** a pass — add a one-test cover if cheap, otherwise leave it `[ ]` and let it feed the inline review as a finding. Never assert an invariant holds without citing the evidence. Skip entirely for simple stories or stories with no invariants.
2. **Design verification (UI stories):** if the story changed user-visible UI, execute **VERIFY** from `skills/design-verify/SKILL.md` — render the changed surfaces (simulator or dev server + screenshots), compare against the Design Contract, and write results to `### Design Verification` in the story file. Mismatches feed into the inline review triage below as findings. If no rendering tooling is available, record the manual checklist and continue. Skip entirely for stories with no user-visible surface.
3. Run code-review inline (don't stop). Continue directly to Code Review below.

---

## Inline Code Review

The diff is uncommitted changes. Story file is loaded. Go straight to three passes.

### Three Passes

**Pass A — Blind Correctness:** Logic errors, null dereferences, unchecked returns, injection/auth/data exposure, races, leaks, error handling.

**Pass B — Edge Case & Regression:** Boundary checks, error paths, callers outside diff, unchecked assumptions.

**Pass C — Acceptance Audit:** Unimplemented/partial ACs, AC contradictions, ignored constraints, files touched/not touched. Include any `[ ]` UNVERIFIED invariants from `### Invariant Verification` as findings.

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

### Re-verify Green

After patches and deferred-item resolution touch the code, **re-run the Build & Test Gate** (build + tests). A static "this fix looks right" is not acceptance — a patch is only resolved once the toolchain confirms it compiles and tests stay green. If the re-run is red, the patch is not done: fix and re-run, or leave the finding `[ ]` and keep Status `in-progress`. Skip only if no code changed during review (clean review) or the gate was `manual-required`.

### Wrap Up

**All resolved (and Build & Test Gate green):**
1. Set `status: done` in the YAML frontmatter
2. **CLOSE-ISSUE** (skip if unavailable)
3. **Operational doc sync (routed to a cheap model — do not do this inline under the flywheel):** doc maintenance is mechanical Haiku-class work and must not run on the dev model (Opus on Swift). If you are running as the `lw-story-developer` subagent, **do not** run docs-sync yourself — just set `INFRA TOUCHED: yes` in your report when this story's File List includes an infra-shaped file (dependency manifest, `.env`/config, migration/schema, script, Dockerfile/CI/deploy, or a new service entrypoint); the orchestrator spawns `lw-docs-sync` (Haiku) to do it. If you are running **standalone** (not under a flywheel), spawn `lw-docs-sync` yourself with this story's path for the **OPERATIONAL** op, or — if subagents are unavailable — execute **OPERATIONAL** from `skills/docs-sync/SKILL.md` inline as a fallback. Record any `DOCS UPDATED` in the Debug Log.
4. **Ledger:** if `docs/metrics/` exists, append one `dev-story` line to `docs/metrics/flywheel-ledger.jsonl` (single shell redirect — do not read the file into context): `{ts, story, phase:"dev-story", model, build_test, bt_iterations, evals:"P/T", findings:{patched,decisions,deferred}, invariants:"V/T", docs_updated:[…], duration_min}`.
5. Report: "{epic}.{story} complete. {P} patches, {D} decisions, {W} deferred.{ Docs: {list} if any}"

**Unresolved patches remain:**
1. Set `status: in-progress` in the YAML frontmatter
2. **TRANSITION** to `in-progress` (skip if unavailable)
3. Report which items need attention
