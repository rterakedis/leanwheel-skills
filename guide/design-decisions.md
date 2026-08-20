# Design decisions

The *why* behind leanwheel's divergences from upstream and from its own earlier shapes.
Each entry is generic — "a SwiftUI + Core Data project", "an iPadOS epic" — never a named
project. The skills cite these as `DD-NN`; `.claude/skills/CLAUDE.md` keeps only the
one-line *what to preserve on sync* per skill and points here for the reasoning.

Not to be confused with a user project's `docs/project/decisions.md` (owned by the
`decision-log` skill) or `docs/deferred-items.md` (owned by `deferred`).

## Contents

- Principles: DD-01 verifiable artifacts over guardrails · DD-02 contract vs conduct · DD-03 fail loudly
- Verification: DD-10 verify by running · DD-11 gate integrity · DD-12 Fix-Now · DD-13 evals command-default · DD-14 invariant evidence
- Orchestration: DD-20 subagent routing · DD-21 non-return rule · DD-22 orchestrator-owned tracking · DD-23 epic-context cache gate · DD-24 docs-sync audiences · DD-25 boundary merge
- Testing & test plans: DD-30 manual pass at the epic boundary · DD-31 TESTING PLAN split + subtract · DD-32 plan-defect kind · DD-33 done stories immutable · DD-34 testability foundation · DD-35 flow tiering · DD-36 e2e backfill
- Simulator automation: DD-40 sim.sh + route navigation · DD-41 silent-failure guards · DD-42 orientation · DD-43 store preset · DD-44 sim.json committed
- Planning & docs: DD-50 planning consolidation · DD-51 pinned story frontmatter · DD-52 design contract decoupled from docs/ux · DD-53 simplicity doctrine placement · DD-54 CLAUDE.md tiers & budget · DD-55 epic archive · DD-56 dark patterns · DD-57 doc-free lane · DD-58 architecture promotion
- Packaging: DD-60 hooks for hard rules · DD-61 no project names

---

## Principles

### DD-01 — Verifiable artifacts over guardrails
**Context.** An instruction mid-skill ("also generate the epic context cache") ran inside a
subagent whose report never named it; a 9-story epic ran end-to-end with the cache never
created and nothing noticed (DD-23).
**Decision.** When a skill must produce something, make it a **named deliverable in the
subagent's report contract** plus a **zero-token orchestrator gate** (`[ -f … ]`, a grep, a
script exit code). Do not add prescriptive prose about *how* to produce it.
**Consequence.** Every "must" in the repo should be traceable to a report field, a file the
next step checks, or a script — or it is conduct guidance and may be trimmed.

### DD-02 — Contract vs conduct
**Decision.** Emphatic language (MUST / never / HALT) is reserved for *contracts*: report
field names and shapes, file formats other skills parse, gate outcomes, immutability and
irreversible-action rules. Everything else is written as plain guidance and trusts the
model's judgment. Each contract has **one canonical home**; other skills cite it.
**Why.** Claude 5-generation guidance removes over-constraint, but repeatability across
sessions depends on the shapes staying byte-stable. Keep the shapes hard, relax the prose.

### DD-03 — Fail loudly
**Context.** Two mechanisms silently dropped their inputs (DD-41) and produced plausible
wrong output; a bare launch flag the app ignored produced a false test finding (DD-31).
**Decision.** Any mechanism that can drop a route, seed, flag, or assertion must either fail
with a named error or be listed in the relevant "when it goes wrong" table. "Searched and
found zero" over a new measurement channel needs a positive control first.

## Verification

### DD-10 — Verify by running, not by reading
**Context.** Sonnet-class dev passes verified code by reading it and regressed already-fixed
items across stories — Swift especially (result builders, macros, actor isolation defeat
static reasoning).
**Decision.** dev-story's Build & Test Gate runs the real toolchain before a story leaves
`in-progress`; code-review re-runs it after patches. Red = not done; HALT rather than loop
past three consecutive reds.

### DD-11 — Gate integrity (fail-first, enumeration bound, positive control)
**Context.** One 14-story epic shipped five gates that could not fail (a grep over an empty
walk, a test asserting the summary line of a different target…).
**Decision.** A *new* test/eval/assertion counts only once **shown to fail** (break →
named failure → restore → green; `scripts/sabotage.sh` makes this mechanical). Enumerating
gates assert a lower bound. Migration-shaped stories write the invariant test as Task 1.
`evals` RUN fails any `output-contains` case with empty stdout.

### DD-12 — `[Fix-Now]` disposition
**Context.** With only Patch/Defer, trivially-fixable out-of-AC findings defaulted to the
deferred log (13 → 27 open in one epic).
**Decision.** code-review owns a four-condition ceiling (≤~10 lines one file adjacent to
the diff; provably safe; no dependency/schema/API/copy change; one-line describable).
Applied findings are recorded `[x] [Fix-Now]` so they stay reviewable; `deferred` intake
rejects items that meet the bar.

### DD-13 — Evals default to `type: command`
**Decision.** The regression net is shell commands (zero model tokens); LM-judge cases are
opt-in and flagged. Cases accumulate per epic and the cumulative set runs at dev-story,
code-review, and the epic boundary.

### DD-14 — Invariants need evidence
**Decision.** A Behavior Contract invariant passes only with a test name or an enforcing
`file:line`; otherwise it stays `[ ] UNVERIFIED` and feeds review as a finding. Never a
prose "it holds."

## Orchestration

### DD-20 — Subagent model routing (re-verify on each model generation)
**Decision.** Create/review phases default to Sonnet; dev-story runs Opus **only on Swift
projects**; docs-sync runs Haiku at low effort. Routing is a per-spawn `model` override
from the orchestrator, never a `/model` switch.
**Rationale (dated to the Claude 4 generation).** A Sonnet Swift dev pass tended to fail
the Build & Test Gate and loop, and each failed `xcodebuild` retry cost more than one
accurate Opus pass; on Python/web Sonnet passed first-try often enough that Opus was
overspend.
**Re-verify.** This is an empirical claim about a model generation. The evidence is
`docs/metrics/flywheel-ledger.jsonl` — `bt_iterations` by model, which `/retrospective`
now reports per epic. Change the routing when the numbers say so, not the prose.

### DD-21 — Non-return rule and wait loops
**Context.** A subagent ended a long build with "I'll wait for the suite to notify me" and
the orchestrator advanced; elsewhere a wait loop keyed on "no xcodebuild process anywhere"
and exited while a sibling story's build was running.
**Decision.** A report missing any required field is a non-return — resume the subagent,
don't advance. Wait loops key on a PID or artifact. Canonical text lives in story-flywheel;
each agent def carries a one-line reinforcement because the agent cannot see it.

### DD-22 — Orchestrator-owned GitHub tracking
**Context.** Cold subagents dropped issue transitions and nothing verified them; issues
drifted (stale `backlog` beside `ready-for-dev`, done stories never closed).
**Decision.** The flywheel drives `gh-track.sh transition|close` itself at each commit
point; the script strips stale status labels and self-verifies; `sync` reconciles at the
boundary. Skills fall back to raw `gh` only when the script is absent.

### DD-23 — Epic-context cache is a gated deliverable
**Decision.** `lw-story-creator` reports `EPIC CONTEXT: generated | reused`; the flywheel
checks `[ -f docs/epics/epic-{N}-context.md ]` after create and re-spawns if missing.
code-review flags a missing cache but never stubs one (a stub newer than prd/architecture
would satisfy the timestamp check and silently replace the distillation). The origin of
DD-01.

### DD-24 — docs-sync: three audiences, one skill, cheapest model
**Decision.** Human operational guides (`docs/setup|maintainer|sql`, OPERATIONAL), the LLM
planning doc (`docs/architecture.md`, PROMOTE), and external-sourced coding guidance
(`docs/setup/swift|web`, DRIFT flags only — `/refresh-*` owns edits) are kept separate.
Runs as the `lw-docs-sync` Haiku subagent spawned by the orchestrator, never inline on the
dev model.

### DD-25 — Squash-merge at the epic boundary (conditional)
**Decision.** Only when the manual pass needs a build the user drives (Apple/native) and
the project's CLAUDE.md prescribes merge-at-boundary. Findings become a new remediation
story, so nothing rides the epic PR; merging first puts the app and the test plan on
`main` where the user builds and annotates.

## Testing & test plans

### DD-30 — Manual testing waits for the epic boundary
**Decision.** Within an epic, stories are interdependent; tapping through after story 2
of 6 surfaces "bugs" that are later stories not built yet. Automated per-story gates catch
real compounding bugs; the human integration pass runs once, over the whole epic, from a
rolled-up plan.

### DD-31 — TESTING PLAN split and the subtract pass
**Context.** The per-story plan field mixed "what I automated" with "what a human should
check"; the boundary roll-up deduped across stories but never subtracted what tests
already pinned. On an iPadOS epic nearly every section-A step the owner walked was already
asserted by UI flows, unit suites, or evals; the only real findings were things automation
structurally cannot see (a layout wrap, a missing feature, a harness footgun). A bare
launch flag the app only honours alongside `--seed` produced a false finding.
**Decision.** dev-story reports `AUTOMATED:` (names) and `MANUAL:` (tagged *why*: visual-
judgment / device-only / sandbox-only / setup-unreachable). The boundary greps flows,
unit target, and `docs/evals/` for each candidate step; covered steps leave the checkbox
list and are named on the flow's `Automated — do not re-test:` line. Every Starting state
prints the exact setup command with every flag. Rule: *a plan step that restates an
existing automated assertion is a defect of the step.*

### DD-32 — `plan-defect` finding kind
**Decision.** When a tester notes a step was already automated and passing, harvest-findings
logs it pre-checked, never stories it, removes the step from the plan, and the retro counts
it as wasted human time — a finding about the plan, not the product.

### DD-33 — Done stories are immutable
**Decision.** Post-test fixes land in a new story `{N}.{last+1}`, never by reopening
`status: done` work. Enhancements are backlog candidates, never remediation ACs;
questions surface for a decision. Remediation ACs fold back into the test plan so a re-test
proves the fix.

### DD-34 — Testability foundation story in Epic 1 (Apple)
**Context.** A 10-epic SwiftUI + Core Data app had the testability guidance on disk and
never adopted it: 354 interactive elements, zero identifiers, no seed scenarios, no UI test
target. Asked to drive the simulator, the model guessed tap coordinates from screenshots
and produced nothing at high token cost.
**Decision.** `/epics` requires an early foundation story (`SeedScenario`, `--seed/--uitest/
--reset`, identifier convention, one XCUITest target); `check-readiness` blocks without it;
`create-story` names identifiers/route/seed in the Design Contract up front; an advisory
hook warns on new interactive elements without identifiers.

### DD-35 — Flow tiering
**Context.** "Identifiers when a flow needs them" × "flows only once stable" let a 9-screen
epic ship with zero drivable surface; four UI-layer bugs invisible to unit tests reached
the manual pass.
**Decision.** Per screen: Tier 1 route + landmark identifier in the screen's story; Tier 2
one write-flow when read/write ACs land (the only tier that catches silent no-op
mutations); Tier 3 detailed assertions after the manual pass. Appearance-only rewrites
break zero flows — structural evidence, not a reason to defer.

### DD-36 — e2e-tests reintroduced
**Decision.** All story-scoped testing was forward-looking; brownfield code, pre-evals
features, and the manual plan had no automation path. `/e2e-tests` authors flows for
existing features, registers them as command evals, and removes converted steps from the
epic test plan (naming them on the `Automated — do not re-test:` line).

## Simulator automation

### DD-40 — `sim.sh` and route-based navigation
**Decision.** One scaffolded script (`doctor/boot/install/launch/shots/dump/flow/…`),
executed never read; config derived once into `.leanwheel/sim.json`; artifacts self-ignore.
Navigation is by named route through one `.onOpenURL` table with two deliveries: the real
URL for attended runs, a `--route` launch argument dispatched in-process for unattended
ones.
**Revision.** iOS 26 interposes an "Open in <App>?" alert on any external custom-scheme URL,
including `simctl openurl` against a running app, so the original one-launch-per-matrix
rationale died; `shots` still costs one launch per device because appearance/text-size are
`simctl ui` toggles. Dismissing the alert is worth exactly one XCUITest flow.
**Verified toolchain facts (Xcode 26.x).** `-showBuildSettings -json` needs a
`-destination`; `INFOPLIST_FILE` resolves against `SRCROOT`; usage-description keys live
in Info.plist *or* `INFOPLIST_KEY_*`; `plutil -extract` parses JSON; no `timeout` on macOS;
no `simctl` subcommand dumps an accessibility hierarchy (XCUITest `debugDescription` +
`xcresulttool` is the supported path); a wedged permission alert survives relaunch
(`--fresh`); `simctl privacy` has no service for camera / Face ID / Bluetooth / ATT /
notifications.

### DD-41 — Two silent-failure regression guards
1. `find <abs-root> -not -path "*/.*"` excludes the whole tree when any ancestor is hidden —
   which is exactly where this framework's session worktrees live. `find_container()`
   searches relative to the project dir.
2. Neither bare `KEY=value` xcodebuild args nor `SIMCTL_CHILD_*` reach an XCTest runner's
   environment; `--route/--seed` were dropped with no error. Use `TEST_RUNNER_<NAME>`.
Both are REGRESSION GUARD comments at the point of use. General lesson in `simulator.md`:
a capture that looks like the launch screen is a dropped route until proven otherwise.

### DD-42 — Orientation control
**Decision.** There is no `simctl` orientation command, so orientation rides the existing
channels: a `--orientation` launch argument (app-side `requestGeometryUpdate`) for
`launch/shots`, `TEST_RUNNER_LW_ORIENTATION` for `dump/flow`. `shots` verifies aspect ratio
and hard-fails on mismatch; a single flag per invocation, never a matrix axis.

### DD-43 — `shots --store` preset
**Decision.** Store captures use a separate `store_devices` pair at native pixels, stable
timestamp-free paths, and a size check that dies on non-accepted store sizes. `--locale`
passes `-AppleLanguages "(ll-RR)"` as separate argv elements (the parenthesised value must
survive as one argument).

### DD-44 — `.leanwheel/sim.json` is committed
**Decision.** Derived values are machine-independent (container path relative to repo
root; no recorded build dir — `sim.sh` always builds into its own DerivedData), so the file
can be shared and `devices` edited in one place; it self-heals when the container moves.

## Planning & docs

### DD-50 — Planning consolidation
**Decision.** `product-brief`, `forge-idea`, `prd`, `ux`, `architecture` are thin aliases
(descriptions kept for triggering) whose flows live in `ideate` (decision loop over the
`elicit` engine) and `spec` (renders docs from `docs/project/decisions.md`). Credited to
Matt Pocock's Wayfinder skill as an idea-port; nothing is named "wayfinder" or "grill*".

### DD-51 — Pinned story frontmatter
**Context.** `status` lived in the body while `github_issue` lived in frontmatter; one
project produced three file shapes and SYNC silently skipped the body-status variants.
**Decision.** `status:` and `title:` are YAML frontmatter — the single machine-readable
source — and a body `**Status:**` line is forbidden. `gh-track.sh` tolerates the legacy
shape on read.

### DD-52 — Design Contract decoupled from `docs/ux/`
**Decision.** Identifiers, deep-link route, and seed scenario are named in every UI
story's Design Contract even when the project has no design system; dev sessions read the
contract, never `docs/ux/` directly.

### DD-53 — Simplicity doctrine as a pointer
**Decision.** `docs/setup/simplicity.md` is installed in every project and referenced from
CLAUDE.md by one line, never inlined — CLAUDE.md loads every turn. Same ladder is applied
at story-authoring (create-story), review (Pass F), and stack time (architecture).

### DD-54 — CLAUDE.md tiers and the 300-line budget
**Decision.** Project CLAUDE.md carries a tier preamble and a 300-line advisory budget
(hook + retro audit). Over budget means demote or move to a nested CLAUDE.md, never append.
This repo's own nested `.claude/skills/CLAUDE.md` follows the same rule.

### DD-55 — Epic archive: condense and cut-release
**Decision.** `docs/epics.md` duplicates ~85% of each done story's weight; CONDENSE collapses
done stories to one row (keyed off the retro stamp), CUT-RELEASE moves the file to
`docs/epics/releases/` with continuous numbering (renumbering would break milestone titles,
filenames, deferred refs). Story files are never moved — create-story finds the next story
by "entry with no file". The flywheel ledger rotates at the same boundary.

### DD-56 — Engagement & Persuasion / dark patterns
**Decision.** UX Discovery probes five behavioral levers, each with an honesty check; dark
variants are named and rejected at design time, flagged at review (Pass E), and warned at
write time (advisory hook).

### DD-57 — Doc-free lane
**Decision.** `dev-single-goal` composes create-story's grilling, quick-dev's frozen-intent
spec, and dev-story's gates for folders with no leanwheel docs; spec lands in a
self-ignoring `.leanwheel/goals/`; escalation to the full lifecycle is offered only on
signal.

### DD-58 — Architecture promotion
**Decision.** Per-epic learnings in `docs/epics/epic-{N}-context.md` are promoted to
`docs/architecture.md` at the boundary (PROMOTE, idempotent) so the next epic plans against
live docs; `docs/setup/*` is never written by it.

## Packaging

### DD-60 — Hooks for hard rules, prose for judgment
**Decision.** "Never do this" is a PreToolUse hook (secrets guard, exit 2); "you probably
want to" is an advisory PostToolUse hook; everything else is skill prose. Hooks are
bash/grep, zero tokens.

### DD-61 — No project names in shipped files
**Decision.** Skills, stubs, agents, and scripts never name the project a lesson came from.
Provenance is recorded here, generically ("a brownfield SwiftUI + Core Data project").

### DD-62 — Ledger appends go through `scripts/ledger.sh`; no qualified PASS
**Decision.** Skills never hand-write flywheel-ledger JSON. `scripts/ledger.sh` owns the
schema: UTC timestamp stamped by the script, model names normalized (lowercase, no
`claude-` prefix, dots→dashes), `build_test` and `rubric_gate` are strict enums with
qualifiers routed to `build_detail`/`notes` (notes capped at 300 chars), and the
verify-green gate rule is enforced mechanically — `rubric_gate: PASS` with a red or
blocked `build_test` is refused; a blocked verify caps a review at `in-progress`.
**Why.** Eight epics of real ledger data from a SwiftUI + Core Data project showed
model-written lines drift immediately: 10 model-name variants, 6 phase-key shapes,
free-text statuses ("green (233/233)", "PASS(pending verify-green)"), 300-word notes
essays, and roll-up lines emitted for only a fifth of flywheel stories. The README's
drift indicators and DD-20's bt_iterations-by-model evidence base were unqueryable
exactly when they fired. Same move as DD-22 (`gh-track.sh`) and DD-11 (`sabotage.sh`):
mechanics in a zero-token script, policy in the skill.
