---
name: dev-story
description: Implements a story from its story file task by task, runs the Build & Test Gate by actually building and testing, verifies invariants and UI design, then hands off to an independent reviewer instead of reviewing its own diff. Use when a story is ready-for-dev, or when the user says "dev story", "implement story", or "dev {story file path}".
---

# Dev Story Skill

**Goal:** Implement all tasks until ACs satisfied and DoD passes.

**Iron rule:** Only stop when: (a) all tasks done and DoD passes, (b) HALT condition, or (c) user says stop.

## Activation

1. Identify story: user path or first `Status: ready-for-dev` in `docs/epics/`. Stop if not found.
2. Read story file completely.
3. Read CLAUDE.md if exists (may override Dev Notes).
4. **Apple platform project** (`docs/setup/swift/` exists, or an `.xcodeproj`/`Package.swift` is present): read [apple-project.md](apple-project.md) — it routes the `docs/setup/swift/` files to read for this story's tasks, before implementing.
4b. **Web/SSG project** (`docs/setup/web/` exists, or `package.json` is present): read [web-project.md](web-project.md) — it routes the `docs/setup/web/` files to read for this story's tasks, before implementing.
4c. **Design contract** (UI stories): if the story changes user-visible UI, read [ui-stories.md](ui-stories.md). A `### Design Contract` in Dev Notes is the design source of truth.
5. Execute **TRANSITION** with `new_label: in-progress` (skip if unavailable).
5b. Record the review base: `git rev-parse HEAD`. The reviewer diffs everything since it, committed or not — note any unrelated uncommitted changes in Completion Notes.
6. Confirm: "Implementing {epic}.{story}: {title}. Starting..."

## Execution

For each task in order:
1. Read task. Understand file, action, outcome.
1b. Apply the simplicity ladder from CLAUDE.md's `## Simplicity & Anti-Over-Engineering` — after understanding the task, not instead of: reuse before rewrite, stdlib/native before a new dependency, and write the least code that satisfies the AC.
2. Implement.
3. Check box: `[ ]` → `[x]`.
4. If problem found, log in Debug Log; continue.

Don't ask for clarification (use Dev Notes; log ambiguous calls in Completion Notes).

**Manual steps belong to the user.** If Dev Notes has a `### Manual Steps` subsection (see create-story ▸ *Manual steps*), surface those steps to the user verbatim rather than attempting or silently skipping them. If the story didn't already verify a named GUI/console path, check it against the installed toolchain version first.

**Migration-shaped stories: the invariant test is Task 1.** If Dev Notes says `**Shape:** migration`, or the story's core is plainly a repeated mechanical change even if unlabeled, read [migration-stories.md](migration-stories.md) before the first edit.

**Keep testability current as you go** (Apple projects with `docs/setup/swift/testability.md`): seed scenarios, identifiers, and deep-link routes land in the same task — see [apple-project.md](apple-project.md) → *Keep testability current as you go* (DD-34).

**Keep files maintainable as you go.** If a file you create or touch crosses the file-size / decomposition target in the routed guidance (`docs/setup/swift/ui-composition.md` or `docs/setup/web/`), decompose it as part of the task, not later. Split along responsibility seams (Swift: `extension TypeName {}` files, named `private struct` sub-views), not by line count; a sub-view gets no data access of its own.

After major task groups, suggest `/compact` if context heavy; continue.

## HALT Conditions
Stop if:
- Required file/dependency missing and can't infer
- AC contradictory or impossible
- Task requires out-of-scope changes risking breakage
- **Build or test suite cannot be made green** after 3 consecutive red runs (see Build & Test Gate escalation limit; `blocked` environment faults don't count — they pause, not HALT). Do not mark the story `review` over a red build — report the failing output and HALT.

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

**Maintainer doc gate:** if the story introduced a new external dependency, a build-system change, or a new platform capability, its maintainer runbook/doc exists or is updated **before** the story is marked done, not left as an action item.

**Never reopen a `done` story.** `status: done` stories are immutable; new work becomes a new story `{N}.{last+1}` (canonical rule: `skills/harvest-findings/SKILL.md`).

## Build & Test Gate

**Verification is by running, not by reading.** Static reasoning is not a substitute for the toolchain — especially for Swift, where result builders, macros (`@Observable`/`@Model`), actor isolation, and `some View` produce errors that cannot be reliably predicted by reading. Before the story can leave `in-progress`, the project must **compile clean and its tests must pass this session** — verified by actually invoking the toolchain, not by inspection.

1. Detect the toolchain and run a real build + test:
   - **Apple / Swift** (Activation step 4's trigger): mandatory — the `xcodebuild` / SwiftPM invocation is in [apple-project.md](apple-project.md) → *Build + test command*. **Scope differs on Swift:** targeted suites and flows while iterating, one full plan before handoff, and the matrix / epic evals / release guard left to the flywheel's final cycle — [apple-project.md](apple-project.md) → *Gate scope* (DD-84). Every other stack runs its whole suite here, each time.
   - **Web / SSG** (`package.json` present): the project's build + test scripts, quiet reporter — see [web-project.md](web-project.md) → *Build + test command*.
   - **Other toolchains:** run the project's documented build + test command — quiet flag if it has one, `tee` to `.leanwheel/logs/`, tail into context.
   - **Quiet output is the rule:** toolchain output is re-sent on every later turn. Full log on disk (`.leanwheel/logs/build-test.log`) for the failing-line cite; only the tail enters context. If `CLAUDE.md` has `## Quiet commands`, use those invocations verbatim.
   - **No toolchain detected:** record a `Build & Test Gate: manual-required` note in the Debug Log with the exact command a human should run, and continue. Never fake a green result.
1c. **String Catalog (Apple, any tracked `*.xcstrings`):** once green, execute **CHECK** from `skills/sync-string-catalog/SKILL.md`.
   - `drift` → **SYNC** (review keys, commit the catalog on the branch), re-check.
   - `unavailable` → `blocked` (2 below), never green.
   - Log its `CATALOG:` line.
2. **Red build or failing test = not done.** Read the compiler/test output, fix the cause, and re-run. Loop until green. Do not patch the story file to `review` over a failure.
   - **Escalation limit:** after **3 consecutive red runs** with no new fix succeeding, stop, report the failing output, and ask the user — do not keep retrying (retry thrash burns tokens and, on GUI toolchains, ties up the device/UI). This is the HALT condition above.
   - **Environment fault ≠ red (DD-80).** A run that fails without naming a compile error or a test — the toolchain, device, or a service it needs is unavailable, or CLAUDE.md's `## Probe` command fails when re-run — records `blocked`, not red: it does not count toward the three and gets no code fix. A second consecutive one pauses the story as an environment fault (report the probe result / log tail) instead of HALTing it as broken.
2b. **A flaky or hanging test suite is a first-class bug — file it the moment it is observed**, via **LOG-AND-SCHEDULE** in `skills/deferred/SKILL.md`. Never "it passes in isolation, ignore it": a festering hang blocks the next epic-boundary gate and masquerades as agent or dev failures. Then continue with the targeted/known-good invocation.
3. **Run the cumulative eval set.** If `docs/evals/` exists, run `bash scripts/evals.sh --epic {n} --quiet` (zero-token; its last line is the RUN report, per evals → RUN) — on Swift, only this story's cases (*Gate scope*). A failing case is a **regression** of an earlier story — treat it exactly like a red build: fix and re-run, or HALT.
4. **Update the eval set.** If `docs/evals/` exists and this story added tests that cover an AC or invariant, execute **BUILD** from `skills/evals/SKILL.md` to append (or flip `enabled: true` on) the corresponding `type: command` cases, so the next story inherits them.
4b. **A new gate is not done until it has been shown to fail.** Scope: every test, eval case, or assertion **written this story** (not every run of the existing suite).
   1. Break the thing it guards — revert the fix, reintroduce the defect, or corrupt the input.
   2. Confirm the gate fails **and names the specific item**.
   3. Restore, confirm green. A gate only ever seen green is unverified.
   4. Record the discriminating check in Completion Notes (`{gate} — sabotage: {what was broken} → failed naming {item}; restored green`) so a reviewer can see it happened.

   **Use `scripts/sabotage.sh` for the revert-the-fix mode** (zero-token, deterministic): `scripts/sabotage.sh --name {TestName} -- {filtered gate cmd}` stashes the non-test changes, runs the *filtered* gate expecting a red that names the item, restores, and re-runs expecting green — its last line (`SABOTAGE OK` / `GATE CANNOT FAIL` / `GATE RED BUT UNNAMED`) is the Completion Notes entry. Reserve model-driven sabotage (reintroduce a defect / corrupt an input) for gates the revert can't exercise.

4c. **Any gate that enumerates must assert it enumerated.** A test that walks a source tree, globs files, or greps the codebase must assert a plausible lower bound on what it found and fail if the count is implausible — otherwise it passes vacuously when a moved directory or broken path returns zero items.

4d. **Before accepting a zero as proof, prove the channel can see a one.** When verification takes the form "search output for X and find none," first produce an X deliberately and confirm it appears on the channel being searched. An unvalidated zero is not evidence of absence. Needed only for a **novel or assumed** channel (a log stream, a grep over runtime output) — not for ordinary test output.

4e. **Pinned counts are never edited by hand** (any stack) — test totals, suite lists, matrix cells a scorer compares against change only through the project's reset script; pins with no script are a finding, not a hand edit (`skills/story-flywheel/final-cycle.md` → *Pinned counts*).

5. Record the result in the Debug Log: each command run, the log it wrote, and `build+test green` (or the manual-required note), plus `evals: P/T`. The same facts go in the report's `RAN` field — what you list there is what the reviewer and orchestrator may treat as proven.

## On Completion

When tasks done, DoD passes, **and the Build & Test Gate is green** (or manual-required is recorded):

**Verify reachability, not presence.** A string, control, or affordance existing in source is *not* evidence it renders — dev, review, and automated validation can all pass while only confirming the string is in the source. Confirm by driving the app or dumping the view hierarchy. **Corollary:** when a UI element can't be addressed in a UI test, dump the tree before blaming the test framework — the element may not exist.

1. **Invariant verification (stateful stories):** if the story's `### Behavior Contract` lists invariants, verify each one holds in the built code with **evidence** — a test that exercises it, or a cited assertion/guard in the source (`file:line`).
   - Record results under `### Invariant Verification` in the story file: each invariant as `- [x] {invariant} — {test name | file:line}` or `- [ ] {invariant} — UNVERIFIED: {why}`.
   - An invariant with no test and no enforcing code is **not** a pass (DD-14) — add a one-test cover if cheap, otherwise leave it `[ ]` — the reviewer turns it into a finding.
   - Skip for stories with no invariants.
2. **Design verification (UI stories):** if the story changed user-visible UI, execute **VERIFY** from `skills/design-verify/SKILL.md` and write results to `### Design Verification` — steps in [ui-stories.md](ui-stories.md) → *Design verification*. Skip entirely for stories with no user-visible surface.
3. **Hand off for independent review.** You never review your own diff (DD-75): the reviewer is a fresh context that never saw your reasoning. **Standalone** (not the `lw-story-developer` subagent): read [standalone-run.md](standalone-run.md) for steps 2 and 5.
   1. Set `status: review` in the YAML frontmatter, then **TRANSITION** to `review` (skip if unavailable).
   2. **Operational doc sync** (cheap model, DD-20/DD-24): as the `lw-story-developer` subagent, do not run docs-sync — report `INFRA TOUCHED: yes` when the File List includes an infra-shaped file (dependency manifest, `.env`/config, migration/schema, script, Dockerfile/CI/deploy, new service entrypoint); the orchestrator spawns `lw-docs-sync` (Haiku). **Standalone:** you run **OPERATIONAL** yourself (via `lw-docs-sync`, or inline without subagents). Record any `DOCS UPDATED` in the Debug Log.
   3. **Ledger:** append one `dev-story` line via `scripts/ledger.sh` (never hand-write the JSON — the script owns the schema, normalizes the model name, stamps the timestamp, and no-ops if `docs/metrics/` is absent):
      `bash scripts/ledger.sh dev-story --story {id} --model {model} --build-test green|red|manual-required --bt-iterations {n} --evals P/T --invariants V/T [--docs-updated a,b] [--duration-min n]`
      Status qualifiers ("233/233", "doc-only") go in `--build-detail`, never in `--build-test`.
   4. **Report:** "{epic}.{story} ready for review.{ Docs: {list} if any}", then the **Verification record**, **TESTING PLAN** and **REVIEW HANDOFF** blocks below.
   5. **Start the review.** Under a flywheel (you are `lw-story-developer`): stop here — the orchestrator spawns the reviewer. **Standalone:** you spawn `lw-story-reviewer` yourself with the REVIEW HANDOFF block as the prompt and relay its report — never review in this context.

### Review Handoff (required report field)

Pointers only. Never summarize what you did or suggest what to check — the reviewer's independence is what it is for.

```
REVIEW HANDOFF
STORY: {story file path}
BASE: {the base ref recorded at Activation}
LOG: .leanwheel/logs/build-test.log | none
LOG TREE: {git write-tree sha taken right after the run that wrote LOG} | none
```

`LOG` is a full, unfiltered, green run or `none` — never a filtered one. `LOG TREE` lets the reviewer prove the log still applies instead of re-running it.

### Verification record (required report fields)

Every phase says what it ran and what it only relied on, so the next phase can tell proven from assumed (DD-84). All stacks. A report missing either of the first two is incomplete (under a flywheel, a non-return).

```
RAN: {each run this session: full-plan | targeted({suites/flows}) | evals({scope}) | catalog-check — log path @ tree sha}
RELIED ON: {a log you did not produce this session — path @ tree sha — and what it proves} | none
FINAL CYCLE NEEDS: matrix=full|width-class · release-guard=yes|no    # Swift only; n/a elsewhere
```

- `matrix=full` when the story touches layout, navigation, or the root view; else `width-class`. `release-guard=yes` when it touches a launch argument or DEBUG-only (`#if DEBUG`) code. When unsure, pick the larger — it costs minutes once, and the final cycle is the only place it runs.
- Never list under `RAN` something reasoned about rather than executed.

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
