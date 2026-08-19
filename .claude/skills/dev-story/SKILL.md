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
   - Any story adding views or UI components: also read `docs/setup/swift/accessibility.md`
   - If the project uses SwiftData and the story touches models, queries, or persistence: read `docs/setup/swift/swiftdata.md`
   - Any story adding/changing a persisted model entity, adding user-facing views, or touching launch behavior: read `docs/setup/swift/testability.md` (seed scenarios, launch arguments, deep-link routes, accessibility identifiers)
   - Any story that needs the app *rendered* — screenshot verification, adding a flow, or stabilizing a screen: read `docs/setup/swift/simulator.md` (`scripts/sim.sh`, the screenshot matrix, flow conventions)
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
1b. Apply the simplicity ladder from CLAUDE.md's `## Simplicity & Anti-Over-Engineering` — after understanding the task, not instead of: reuse before rewrite, stdlib/native before a new dependency, and write the least code that satisfies the AC.
2. Implement.
3. Check box: `[ ]` → `[x]`.
4. If problem found, log in Debug Log; continue.

Don't ask for clarification (use Dev Notes; log ambiguous calls in Completion Notes).

**Manual steps belong to the user, explicitly.** If Dev Notes has a `### Manual Steps` subsection (see create-story ▸ *Manual steps*), surface those steps to the user verbatim rather than attempting or silently skipping them — and if the story didn't already verify a named GUI/console path, verify it against the installed toolchain version before the user relies on it (vendors move menu paths between releases; a wrong path is a hard stop for a new operator).

**Migration-shaped stories: the invariant test is Task 1.** If Dev Notes says `**Shape:** migration` — or the story's core is plainly a repeated mechanical change (a rename across N call sites, a type migration across N properties, a dependency swap) even when create-story didn't label it — write the invariant test **before** the edits, run it, and confirm it fails **enumerating every violation**. Then make the edits. At the end, re-prove it by reverting exactly **one** instance and confirming a failure that names that instance. A test written after the sweep is authored against already-corrected code and can only be shown to pass. If the task list is ordered otherwise, reorder it.

**Keep testability current as you go** (Apple projects with `docs/setup/swift/testability.md`): a task that adds or changes a persisted model entity updates the `SeedScenario` registry (at minimum `.typical` and `.edge`) in the same task; new user-facing views get the **exact** `.accessibilityIdentifier`s the story's Design Contract names (never invented, never backfilled); a task that adds a screen adds its deep-link route in the same task.

**Keep files maintainable as you go.** If a file you create or touch crosses the file-size / decomposition target in the routed guidance (`docs/setup/swift/ui-composition.md` or `docs/setup/web/`), decompose it **as part of the task** — don't defer it. Split along responsibility seams (Swift: `extension TypeName {}` files for members, named `private struct` sub-views for layout), never by mechanical line-cutting, and never by giving a sub-view its own data access. A 280-line file with one cohesive job is fine; a smaller file doing three jobs is not — cohesion decides the cut.

After major task groups, suggest `/compact` if context heavy. Don't block; continue.

## HALT Conditions
Stop if:
- Required file/dependency missing and can't infer
- AC contradictory or impossible
- Task requires out-of-scope changes risking breakage
- **Build or test suite cannot be made green** after 3 consecutive red runs (see Build & Test Gate escalation limit). Do not mark the story `review` over a red build — report the failing output and HALT.

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

**Maintainer doc gate:** if the story introduced a new external dependency, a build-system change, or a new platform capability, its maintainer runbook/doc must exist or be updated **before** the story is marked done — never left as an action item for later.

**Never reopen a `done` story.** `status: done` stories are immutable; new work becomes a new story `{N}.{last+1}` (canonical rule: `skills/harvest-findings/SKILL.md`).

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
2. **Red build or failing test = not done.** Read the compiler/test output, fix the cause, and re-run. Loop until green. Do not patch the story file to `review` over a failure.
   **Escalation limit:** after **3 consecutive red runs** with no new fix succeeding, stop, report the failing output, and ask the user — do not keep retrying. Retry thrash burns tokens and, on GUI toolchains, ties up the device/UI. This is the HALT condition below.
2b. **A flaky or hanging test suite is a first-class bug — file it the moment it is observed**, via **LOG-AND-SCHEDULE** in `skills/deferred/SKILL.md`. Never "it passes in isolation, ignore it": a festering hang blocks the next epic-boundary gate and masquerades as agent or dev failures. Then continue with the targeted/known-good invocation.
3. **Run the cumulative eval set.** If `docs/evals/` exists, execute **RUN** from `skills/evals/SKILL.md` for this story's epic (zero-token: it just runs the accumulated `type: command` cases). A failing case is a **regression** of an earlier story — treat it exactly like a red build: fix and re-run, or HALT. This is what makes the regression net *cumulative* across stories, not just per-story.
4. **Update the eval set.** If `docs/evals/` exists and this story added tests that cover an AC or invariant, execute **BUILD** from `skills/evals/SKILL.md` to append (or flip `enabled: true` on) the corresponding `type: command` cases, so the next story inherits them.
4b. **A new gate is not done until it has been shown to fail.** For every test, eval case, or assertion **written this story** (not every run of the existing suite): break the thing it guards — revert the fix, reintroduce the defect, or corrupt the input — and confirm the gate fails **and names the specific item**. Restore, confirm green. A gate that has only ever been observed green is unverified, however many times it ran. Record the discriminating check in Completion Notes (`{gate} — sabotage: {what was broken} → failed naming {item}; restored green`) so a reviewer can see it happened.
   **Use `scripts/sabotage.sh` for the revert-the-fix mode** (zero-token, deterministic): `scripts/sabotage.sh --name {TestName} -- {filtered gate cmd}` stashes the non-test changes, runs the *filtered* gate expecting a red that names the item, restores, and re-runs expecting green — its last line (`SABOTAGE OK` / `GATE CANNOT FAIL` / `GATE RED BUT UNNAMED`) is the Completion Notes entry. Reserve model-driven sabotage (reintroduce a defect / corrupt an input) for gates the revert can't exercise.

4c. **Any gate that enumerates must assert it enumerated.** A test that walks a source tree, globs files, or greps the codebase must assert a plausible lower bound on what it found and fail if the count is implausible — otherwise it passes vacuously when a moved directory or broken path returns zero items.

4d. **Before accepting a zero as proof, prove the channel can see a one.** When verification takes the form "search output for X and find none," first produce an X deliberately and confirm it appears on the channel being searched. An unvalidated zero is not evidence of absence. Needed only for a **novel or assumed** channel (a log stream, a grep over runtime output) — not for ordinary test output.

5. Record the result in the Debug Log: the command run and `build+test green` (or the manual-required note), plus `evals: P/T`. This is the executable regression net that prevents a later story from silently reverting a prior fix — it only works if it actually runs every story.

## On Completion

When tasks done, DoD passes, **and the Build & Test Gate is green** (or manual-required is recorded):

**Verify reachability, not presence.** A string, control, or affordance existing in source is *not* evidence it renders — dev, inline review, and automated validation can all pass while only confirming the string is in the source. Confirm by driving the app or dumping the view hierarchy. **Corollary:** when a UI element can't be addressed in a UI test, dump the tree before blaming the test framework — the element may not exist.

1. **Invariant verification (stateful stories):** if the story's `### Behavior Contract` lists invariants, verify each one holds in the built code with **evidence** — a test that exercises it, or a cited assertion/guard in the source (`file:line`). Record results under `### Invariant Verification` in the story file: each invariant as `- [x] {invariant} — {test name | file:line}` or `- [ ] {invariant} — UNVERIFIED: {why}`. An invariant with no test and no enforcing code is **not** a pass — add a one-test cover if cheap, otherwise leave it `[ ]` and let it feed the inline review as a finding. Never assert an invariant holds without citing the evidence. Skip entirely for simple stories or stories with no invariants.
2. **Design verification (UI stories):** if the story changed user-visible UI, execute **VERIFY** from `skills/design-verify/SKILL.md` — render the changed surfaces (simulator or dev server + screenshots), compare against the Design Contract, and write results to `### Design Verification` in the story file. Mismatches feed into the inline review triage below as findings. If no rendering tooling is available, record the manual checklist and continue. Skip entirely for stories with no user-visible surface.
3. Run code-review inline (don't stop). Continue directly to Code Review below.

---

## Inline Code Review

The diff is uncommitted changes. Story file is loaded. Go straight to the passes below.

### Review Passes

**Pass A — Blind Correctness:** Logic errors, null dereferences, unchecked returns, injection/auth/data exposure, races, leaks, error handling.

**Pass B — Edge Case & Regression:** Boundary checks, error paths, callers outside diff, unchecked assumptions.

**Pass C — Acceptance Audit:** Unimplemented/partial ACs, AC contradictions, ignored constraints, files touched/not touched. Include any `[ ]` UNVERIFIED invariants from `### Invariant Verification` as findings.

**Pass D — Security (conditional):** If Dev Notes has `Security Sensitivity:`, run matching categories from `skills/security-review/skill.md`. Skip if blank.

**Pass E — Design Compliance (conditional):** If the diff touches user-visible UI and a `### Design Contract` (or `docs/ux/DESIGN.md`) exists: hardcoded values where a token exists, missing required states (empty/loading/error), missing dark-mode pair, platform checklist violations (tap targets, Dynamic Type, semantic HTML, focus visibility), near-duplicate of an inventoried component. **Missing or renamed accessibility identifiers**: an interactive element or dynamic row with none, or one that differs from the name the Design Contract assigned (HIGH — a renamed identifier silently breaks every flow and screenshot that addresses it), or one not matching `{feature}-{element}-{role}` kebab-case (MEDIUM). A new screen with no deep-link route is MEDIUM — it is unreachable by `/design-verify` and by future flows. Include any unresolved `### Design Verification` findings. Skip for non-UI diffs.

**Pass F — Over-Engineering:** Hunt complexity only (correctness/security are Passes A–D — don't duplicate). One tagged line per finding: `delete:` (dead/speculative code), `stdlib:` (hand-rolled thing the stdlib ships), `native:` (dependency/code the platform already covers), `yagni:` (one-implementation abstraction, config nobody sets, one-caller layer), `shrink:` (same logic, fewer lines). Never flag a single smoke test / validation / security / accessibility for removal. Route findings as `patch`/`defer` cleanups, never a blocking bug. End with `net: −N lines possible` or `Lean already.`

### Triage

Tag each finding:
- `decision-needed` — ambiguous; fix needs user input
- `patch` — clear bug; unambiguous fix
- `fix-now` — outside the ACs but trivially and safely fixable now (see ceiling)
- `defer` — pre-existing, not from this diff
- `dismiss` — noise or false positive

**`fix-now` ceiling — all four must hold**, or it is `defer`:
1. Small (≤ ~10 lines, one file) and adjacent to the diff already under review.
2. Provably safe — covered by an existing test, or by one written in the same pass.
3. No new dependency, schema change, public API change, or user-visible copy change.
4. Describable in one line in the commit message.

Merge duplicates. Drop `dismiss`.

### Record Findings

Write non-dismissed findings to `### Review Findings` subsection:
- `- [ ] [Decision] {title} — {detail}`
- `- [ ] [Patch] {title} [{file}:{line}]`
- `- [x] [Fix-Now] {title} [{file}:{line}] — out of scope, applied under the fix-now ceiling`
- `- [ ] [Defer] {title} — pre-existing`

`[Fix-Now]` items are recorded, never invisible — a fix applied without an AC still gets reviewed.

### Resolve and Patch

- Zero findings: skip to Wrap Up
- `decision-needed`: list all, wait for answers, record decisions, convert to patch/defer/dismiss
- Auto-patch all `patch` (including resolved decisions). Mark `[x]`.
- Apply all `fix-now` items in the same pass, each with its covering test. Mark `[x]`. Anything that grew past the ceiling while fixing it reverts to `defer`.
- If patch can't auto-apply: surface explicitly, leave `[ ]`

### Pull Deferred Items Forward

After patches, check for `[ ] [Defer]` items in story file. If found, execute **RESOLVE** from `skills/deferred/skill.md`. Surfaces immediately with fresh context.

### Re-verify Green

After patches and deferred-item resolution touch the code, **re-run the Build & Test Gate** (build + tests). A static "this fix looks right" is not acceptance — a patch is only resolved once the toolchain confirms it compiles and tests stay green. If the re-run is red, the patch is not done: fix and re-run, or leave the finding `[ ]` and keep Status `in-progress`. Skip only if no code changed during review (clean review) or the gate was `manual-required`.

### Wrap Up

**All resolved (and Build & Test Gate green):**
1. Set `status: done` in the YAML frontmatter
2. **CLOSE-ISSUE** (skip if unavailable)
3. **Operational doc sync (routed to a cheap model — do not do this inline under the flywheel):** doc maintenance is mechanical Haiku-class work and must not run on the dev model (Opus on Swift). If you are running as the `lw-story-developer` subagent, **do not** run docs-sync yourself — just set `INFRA TOUCHED: yes` in your report when this story's File List includes an infra-shaped file (dependency manifest, `.env`/config, migration/schema, script, Dockerfile/CI/deploy, or a new service entrypoint); the orchestrator spawns `lw-docs-sync` (Haiku) to do it. If you are running **standalone** (not under a flywheel), call the Agent tool yourself — `subagent_type: "lw-docs-sync"`, prompt naming op **OPERATIONAL** and this story's path — or, if subagents are unavailable, execute **OPERATIONAL** from `skills/docs-sync/SKILL.md` inline as a fallback. Record any `DOCS UPDATED` in the Debug Log.
4. **Ledger:** if `docs/metrics/` exists, append one `dev-story` line to `docs/metrics/flywheel-ledger.jsonl` (single shell redirect — do not read the file into context): `{ts, story, phase:"dev-story", model, build_test, bt_iterations, evals:"P/T", findings:{patched,decisions,deferred}, invariants:"V/T", docs_updated:[…], duration_min}`.
5. Report: "{epic}.{story} complete. {P} patches, {D} decisions, {W} deferred.{ Docs: {list} if any}" followed by the **TESTING PLAN** block below.

### Testing Plan (required report field)

Every dev-story report ends with a `TESTING PLAN` split into two named sub-fields. **Both are mandatory** — a `TESTING PLAN` missing either sub-field is an incomplete report (under a flywheel, a non-return: the orchestrator resumes you rather than advancing). The split exists so the epic-boundary test plan can subtract what automation already proves instead of asking a human to re-walk it.

```
TESTING PLAN
AUTOMATED: {flow/suite/eval names that now pin this story's behavior — names only, e.g. `UpgradeSheetFlow`, `CustomerLimitServiceTests`, `docs/evals/epic-12.md#E12-03`. Not assertions, not prose. "none" if nothing automated.}
MANUAL: {only what no test can exercise. One line per item, each tagged with WHY it is manual:
  - {step} → {expected} [visual-judgment | device-only | sandbox-only | setup-unreachable]
  Include the exact setup command when a step needs one (e.g. `scripts/sim.sh launch --uitest --seed heavy --route settings`, an `xcrun simctl` call) — carry every flag the app needs to honour it. "none — fully automated" or "none — no user-visible surface changed" when empty.}
```

Rules:
- An item belongs in `MANUAL` only if you can name the reason a test can't see it. If you can't, it belongs in a test — write the test and list it under `AUTOMATED`.
- `AUTOMATED` is the set of names the boundary greps for; cite the identifier as it appears in the test target / eval file so the grep hits.
- Unknown-reachability ("I'm not sure a test could reach this") is **setup-unreachable**, and says so — it is still a gap worth closing, not a free pass.

**Unresolved patches remain:**
1. Set `status: in-progress` in the YAML frontmatter
2. **TRANSITION** to `in-progress` (skip if unavailable)
3. Report which items need attention
