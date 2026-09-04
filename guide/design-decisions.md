# Design decisions

The *why* behind leanwheel's divergences from upstream and from its own earlier shapes.
Each entry is generic — "a SwiftUI + Core Data project", "an iPadOS epic" — never a named
project. The skills cite these as `DD-NN`; `.claude/skills/CLAUDE.md` keeps only the
one-line *what to preserve on sync* per skill and points here for the reasoning.

Not to be confused with a user project's `docs/project/decisions.md` (owned by the
`decision-log` skill) or `docs/deferred-items.md` (owned by `deferred`).

## Contents

- Principles: DD-01 verifiable artifacts over guardrails · DD-02 contract vs conduct · DD-03 fail loudly
- Verification: DD-10 verify by running · DD-11 gate integrity · DD-12 Fix-Now · DD-13 evals command-default · DD-14 invariant evidence · DD-70 evals RUN is a script and the CI seam
- Orchestration: DD-20 subagent routing · DD-72 effort pinned per runner · DD-21 non-return rule · DD-22 orchestrator-owned tracking · DD-23 epic-context cache gate · DD-24 docs-sync audiences · DD-25 boundary merge
- Testing & test plans: DD-30 manual pass at the epic boundary · DD-31 TESTING PLAN split + subtract · DD-32 plan-defect kind · DD-33 done stories immutable · DD-34 testability foundation · DD-35 flow tiering · DD-36 e2e backfill
- Simulator automation: DD-40 sim.sh + route navigation · DD-41 silent-failure guards · DD-42 orientation · DD-43 store preset · DD-44 sim.json committed · DD-45 release parity for store captures · DD-46 vendored-script drift is reported, never silent · DD-47 runtime pin + ambiguity guard
- Planning & docs: DD-50 planning consolidation · DD-51 pinned story frontmatter · DD-52 design contract decoupled from docs/ux · DD-53 simplicity doctrine placement · DD-54 CLAUDE.md tiers & budget · DD-55 epic archive · DD-56 dark patterns · DD-57 doc-free lane · DD-58 architecture promotion
- Packaging: DD-60 hooks for hard rules · DD-71 per-file budget in bytes · DD-61 no project names · DD-62 ledger via ledger.sh · DD-63 quiet toolchain output · DD-68 optional styling via template.json · DD-69 status line over IDE extension

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

### DD-20 — Subagent model routing (re-verify on each model generation; Opus is the cost ceiling)
**Decision.** All three phase-runner agents pin `model: sonnet`. dev-story gets a per-spawn
`model: opus` override on Swift projects only. docs-sync runs Haiku at low effort. Routing
is always a per-spawn override from the orchestrator — never a `/model` switch mid-session,
which busts the prompt cache. **The flywheel never inherits the session model:** an epic is
dozens of heavy phase turns, and run on a Mythos-tier session model (Fable) it consumed half
a week's usage budget in one epic versus ~25% for multiple epics on the pinned routing. The
pin is the cost ceiling; a stronger session model is for the *orchestrating* conversation,
not the phase spawns.
**Rationale (dated to the Claude 4 generation).** A Sonnet Swift dev pass tended to fail
the Build & Test Gate and loop, and each failed `xcodebuild` retry cost more than one
accurate Opus pass; on Python/web Sonnet passed first-try often enough that Opus was
overspend.
**Re-verify.** The Sonnet-vs-Opus split is an empirical claim about a model generation. The
evidence is `docs/metrics/flywheel-ledger.jsonl` — `bt_iterations` by model, which
`/retrospective` reports per epic. Change the routing when the numbers say so, not the
prose. (An inherit-the-session variant was tried in 2026-08 and reverted for the usage-burn
reason above.)

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

### DD-63 — Quiet toolchain output
**Decision.** Build/test gates run with quiet flags, `tee` the full log to the self-ignoring
`.leanwheel/logs/`, and keep only the tail in context. Scaffolded CLAUDE.md carries a
`## Quiet commands` section with the project's exact invocations. Tool output persists in
the conversation for the rest of the session and is re-sent every turn; on Swift a single
verbose `xcodebuild` run can outweigh the whole story.

### DD-64 — CloudKit schema is a release artifact, not a model property
**Decision.** The Swift stubs and `/appstore-preflight` treat "the CloudKit Development
schema is complete and deployed" as a checked release item. `testability.md` carries the
Core Data pattern — a `#if DEBUG`, `--init-cloudkit-schema`-gated `initializeCloudKitSchema`
call with its device/slowness/throwaway-record caveats; `swiftdata.md` carries the SwiftData
variant (temporary `NSPersistentCloudKitContainer` over
`NSManagedObjectModel.makeManagedObjectModel(for:)`) and cross-references rather than
duplicating. Preflight greps for a CloudKit container with no `initializeCloudKitSchema`
call and raises **HIGH**, plus a TestFlight checklist line for the Console deploy.
**Why.** `NSPersistentCloudKitContainer` ships no schema file: it infers record types from
the managed object model and creates them *lazily in Development*, on first save of that
type. So the Development schema is whatever manual testing happened to touch, *Deploy Schema
Changes* only copies what Development already has, and an entity, attribute, or relationship
never exercised on a dev-signed device is simply absent in Production. It fails for the first
real user who creates one and never for the developer. Nothing in the existing coverage
caught it: `swiftdata.md`'s CloudKit rules govern model *shape* (no `.unique`, optional
relationships), `testability.md` and `swift-audit` govern *detaching* CloudKit from seeded
runs, and preflight's entitlements row checks the container is *provisioned* — three
CloudKit checks, none of which look at whether the schema was ever populated. The launch-
argument gating puts it in `testability.md` alongside the rest of the launch-argument
contract rather than in a new stub. Placement of the failure in the release checklist follows
DD-60's split: it cannot be a hook (needs a device and a Console) and cannot be a test, so it
is prose plus a preflight grep.

### DD-45 — Store captures run in Release parity, and the flag is implied not remembered
**Decision.** `sim.sh` gained `--assetcapture` (parsed by `launch`, `shots`, and `dump`;
delivered to the app as a launch argument, and to `dump` additionally as
`TEST_RUNNER_LW_ASSETCAPTURE` because the runner is launched by `xcodebuild`, not
`launch_app`). `shots --store` sets it **implicitly**. The app-side half — a single
`LaunchArguments.showsDebugAffordances` predicate that every DEBUG-only *view* is gated on,
which **overrides** `isAutomatedRun`, plus a source-walking test that fails naming any file
with ungated DEBUG-only UI — is documented in `testability.md`.

**Why.** A Debug build is a strict superset of Release's UI and the capture pipeline
*requires* the superset: seeding and routing are `#if DEBUG`, so a Release build cannot be
driven to a screen at all. Every `#if DEBUG` view is therefore a standing App Store
screenshot contaminant (Guideline 2.3.3 — a capture may not show controls the shipped app
lacks), and nothing in the toolchain reports it: the capture looks right and the app looks
right. On one SwiftUI project two sites leaked, and one was gated on `isAutomatedRun` — so it
rendered *only* during seeded capture runs, invisible in ordinary Debug testing and present
in exactly the images bound for the App Store. That is also why the predicate must override
`isAutomatedRun` rather than sit beside it.

Three sub-decisions carry the weight. **Implied, not required:** a flag a human must remember
fails exactly like "remember not to screenshot Settings". **Not folded into `--uitest`:** some
debug UI exists *for* tests to assert on, so suppressing it under `--uitest` breaks those
gates — a capture run and a UI test are different intents that merely share a Debug binary.
**Gating resolved per file, not per block:** a section gated at its call site with its body in
a separate `#if DEBUG` block is correct code that a per-block rule flags, and a guard with
false positives gets deleted; the enforcing test also asserts a lower-bound count so it cannot
pass vacuously when a directory moves.

### DD-46 — Vendored-script drift is reported, never silent
**Decision.** Two signals, no behavior change. `/appstore-connect` ASSETS gained a
**capability** precondition: it greps the project's `scripts/sim.sh` for each mode it
actually invokes (`--store`, `--locale`, `--assetcapture`) and hard-stops with `run
/upgrade-project to sync scripts/sim.sh`. `/upgrade-project` now reports **capability skew**
for any vendored script it classifies CONFLICT — diffing the shipped copy's long-option
vocabulary against the project's and naming what is absent — while still leaving the file
untouched.

**Why.** `sim.sh` is vendored into projects, copied only when *missing*, so upstream
improvements never reach a project that already has a copy: a stale copy is the steady
state, not an anomaly. On one project the copy predated `shots --store`/`--locale` by over a
week, silently blocking `/appstore-connect assets`; the skill's precondition passed because
`scripts/sim.sh` existed, without checking that it supported the modes ASSETS calls.
`/upgrade-project`'s git-provenance test was *right* to refuse the locally-modified copy —
the gap was that nobody was told.

**Capability, not version.** A version compare drifts out of sync with what the caller
invokes and lies about a locally-modified copy that still supports the modes; grepping for
the flags the skill literally passes cannot. For the same reason skew is reported as flags
present upstream and absent locally only — flags present locally and not upstream are
project-local features, not drift. Consistent with DD-60: a signal a human reads, because
this can be neither a hook nor a test.

### DD-65 — A deterministic-path generator must delete its own stale output
**Decision.** `compose.swift` clears the locale's previously-composed screenshots
immediately before writing the full set from the plan. The clear runs **strictly after**
all-or-nothing validation succeeds, is **skipped under `--dry-run` and `--only`**, removes
**only files matching its own `{order}_{class}_{id}.png` pattern**, and **logs the count**
(`compose: removed 3 stale screenshots (plan changed)`). `asc-lint.sh` separately WARNs on
any screenshot with no matching `screenshots.md` row, so projects that already accumulated
orphans can find them.

**Why.** The output path is fully deterministic, so re-composing an unchanged plan is a
clean in-place overwrite — which is exactly what hides the bug. Any plan edit that changes a
*filename* (reordering a row, renaming an id, deleting a row, narrowing `devices`) leaves the
old file behind forever, and the result is a directory of near-identical screenshots where
nothing indicates which are current. Git does not save you: `docs/store/screenshots/` is
committed, so an orphan is a **tracked, unmodified** file — invisible in `git status`,
invisible in a PR diff. It reads as settled work, and there is no point at which a human
would naturally notice. That is what makes it a code fix rather than a documented step; the
manual workaround it replaces was `rm -rf` on a directory inside the user's repo, and a
documented `rm -rf` outlives the need for it.

**Ordering and scope carry the weight.** *After validation:* the script writes nothing on any
error, so delete-then-fail would leave the user with no screenshots at all — strictly worse
than orphans. *Not under `--dry-run`:* it is the "is my plan valid" probe and has to stay
side-effect free. *Not under `--only`:* that composes a deliberate subset, and wiping the
locale would delete rows the user chose not to recompose; skipping is the safer of the two
available scopings, and a later full run still prunes everything. *Own pattern, not an empty
directory:* `screenshots/{locale}/` is a committed folder in a user's repo that may hold
something a human put there, and a tool that deletes files it did not create is one bad
assumption away from destroying work. *Logged, not silent:* deletion inside a git repo that
nobody is told about is its own failure mode. Same shape as DD-60 — the enforcement is in the
tool, the signal is for the human.

### DD-47 — Device names resolve within a pinned runtime; ambiguity is a hard stop
**Decision.** `.leanwheel/sim.json` gained an optional `runtime` key. `resolve_device` matches
a device name *within* that runtime when it is set; when it is not set and the name matches on
more than one installed runtime, `sim.sh` **dies** naming the runtimes rather than picking one.
Unpinned and unambiguous is unchanged, so no existing project needs a config edit. The pin
applies to `devices` and `store_devices` alike.

**Why.** Device names are not unique across runtimes — a machine doing Xcode-N compatibility
work carries the same `iPhone 17` on two — and the old resolution was "grep the name, `head -1`".
That is a DD-41 silent failure in its purest form: every screenshot, dump, and flow runs against
a different OS than intended, nothing reports it, and the output looks completely normal. A
runtime reshuffle or a new install flips it with no diff anywhere.

**Why refusing beats guessing.** A pin alone would have fixed the reference project, which set
one by hand. But an unpinned project is the default state, and quietly picking the first match is
the exact behaviour that caused the bug. Converting the silent wrong-OS run into a loud stop is
the fix; the pin is how you answer it. The error names the runtimes and shows the literal line to
paste, so the stop costs one edit, once.

**Implementation note worth keeping.** Split the device name off at the **UUID**, never at the
first `(` — real names contain parentheses (`iPad Pro 11-inch (M5)`, `iPad Pro 13-inch (M5)`),
and a first-paren split silently matches nothing for exactly the two store classes
`shots --store` depends on. This was caught by testing a paren-named device, not by reading the
code; the first version of the change looked correct and was not.

### DD-66 — Field knowledge is tracked separately from research knowledge, and is protected from refresh passes

`docs/setup/swift/` (and its `web` sibling) carries two kinds of claim with opposite ageing
behaviour, and until now nothing distinguished them.

**Research knowledge** comes from Apple docs, WWDC, release notes, and curated authors. It goes
stale on the OS/Xcode cadence, and a newer primary source supersedes it outright. Refreshing it
is exactly what `/refresh-swift` and `/refresh-web` exist to do.

**Field knowledge** comes from trial and error on a real shipping project — a mechanism observed,
a symptom paid for, a fix verified by running. It is typically *absent* from any primary source,
which is precisely what makes it valuable, and it does **not** go stale on a version bump. It
retires only when a source shows the underlying **mechanism** changed.

Left undistinguished, a research pass eventually flattens the second kind: it finds current
guidance on the same topic, rewrites the section, and the rule that cost three sessions to
discover disappears with no diff anyone reads as a loss. The failure is quiet and one-directional.

**The convention.** A field-earned rule carries `<!-- FIELD: … -->` immediately after its
heading (once under the H1 for a file that is field-derived end to end). Invisible when rendered,
greppable when not. `docs/setup/swift/PROVENANCE.md` is the canonical statement, is copied into
every scaffolded project, and is named in `/refresh-swift` Step 3.

**The rule for automated passes.** A `<!-- FIELD -->` block may be appended to with a dated
verification note, version-scoped against a citation, or retired into a `## Retired` section with
the citation that shows the mechanism is gone. It may never be silently rewritten or deleted
because newer general guidance covers the same topic. The bar is the mechanism, not the topic:
"Apple now recommends X" does not retire a rule about what happens when X is used near a
translucent bar. When a finding conflicts with a field rule and cannot meet that bar, the refresh
**reports the conflict and changes nothing** — the person who paid for the rule decides.

Same shape as DD-60: the enforcement is a cheap mechanical marker plus one rule about it, rather
than added prose asking the model to be careful.

### DD-67 — The CLAUDE.md guardrails block is a managed pointer, versioned so it can be re-synced

The Swift and Web guardrail sections of a generated `CLAUDE.md` used to be a plain append: the
stub's contents were copied in at scaffold time and then diverged forever. Two costs. First,
whatever was inlined drifts from the reference file it was copied from, and the copy in
`CLAUDE.md` is the one loaded on **every turn** — so the stale version is the one that wins.
Second, `/upgrade-project` could only ever detect the heading's *presence*, so a project scaffolded
a year ago never received a single guardrail update.

The block is now delimited by `<!-- leanwheel:guardrails {surface} vN -->` … `<!-- /… -->` and is
declared managed: it holds a **pointer** to `docs/setup/{swift,web}/` plus the tripwires that must
be known *before* a plan is formed (violating them corrupts data or ships a liability), and
nothing else. Project-specific rules live in `## Critical Rules`, outside it.

`/upgrade-project` reads the version: matching `vN` is a no-op, an older `vN` is a REFRESH that
rewrites the block in place, and a block with **no** marker is a CONFLICT — a pre-managed project
whose block may carry hand-added rules, so it is diffed and offered, never overwritten.
`/refresh-swift` must bump `vN` whenever the block changes; leaving it unchanged means no existing
project ever receives the update, which is the failure the marker exists to prevent.

### DD-68 — Optional per-project styling defaults to the *old code path*, not to a re-derivation of it

`compose.swift` is shared by every project via symlink, so a project that wants its brand in its
App Store screenshots cannot get there by editing it — one project's green would leak into every
other project's renders. Styling therefore lives in an **optional** `docs/store/template.json`,
merged over the built-in plain style per key.

The hard part is not the styling, it is the *absence* of styling. Every project that already
composes screenshots must be unaffected, and "unaffected" has to mean byte-identical output, not
"looks the same" — a silent few-pixel shift in a committed, tracked PNG surfaces to nobody. Two
rules make that hold:

**Defaults are the original expressions, not equivalent-looking ones.** Where a default could be
written either as the old literal or as a value in the new vocabulary, it is written as the old
literal. The auto-shrink multiplier is stored as `0.94`, not derived as `1 - 0.06`, because those
are different doubles and would walk a different shrink sequence on any caption long enough to
shrink. Tracking is omitted from the attributed string entirely when it is zero rather than set to
zero, because an attribute that is present at all can perturb line breaking.

**Where no number can express the old behaviour, the default is `nil`, not a number.** Absent
`captionLeading` means "line height from font metrics × 1.12"; absent `deviceTop`/`deviceWidth`
means "fit the device into the space left below the caption" — a behaviour with no fractional
expression. Setting them opts into the new behaviour (explicit leading, a pinned device that may
bleed off the canvas edge). This is what lets a project override `colors.light.background` alone
and change *only* that.

The corollary is that a rendering change must never be gated on "a template exists". A first
attempt clipped the capture to the bezel silhouette whenever a template was present; that made
mere presence a rendering switch, so a colours-only template silently altered unrelated pixels in
the dark appearance. It became an explicit key (`device.clipCaptureToBezel`) defaulting to whether
a panel is drawn — the condition that actually makes the difference visible.

**A malformed template is a hard, named error that writes nothing**, including an unknown key,
which is how a typo (`backgronud`) fails loudly instead of silently keeping a default. Falling
back to the plain style on a bad template would be the worst outcome available: a wrong-looking
set that reports success. Validation is shallow-checked cheaply by `asc-lint.sh` (hex, fractions,
icon paths) and owned fully by `compose.swift`, which has a real JSON parser.

### DD-69 — Project status is a status line and a GitHub view, not a VS Code extension

The recurring suggestion is an IDE panel showing epic/story progress, in the shape of the
several community dashboards built around the upstream method. The pain behind it is real and
well stated by one of those authors: *"Every morning I was spending 5 minutes of tokens just
asking my AI agent 'where did I leave off?'"* That is a **token and latency** cost, not a
visualization gap — and the two have very different cheapest fixes.

**Why not an extension.** Three things argue against it, in increasing order of weight.

*The category does not retain.* Upstream has 43K stars and at least six independent,
non-converging dashboards — two marketplace extensions, a third viewer extension, a terminal
tracker, a hosted web UI, and the official one. Community response to their announcement threads
was 1 reaction / 0 comments and 5 reactions / 0 comments; the official extension repo sits at 25
stars. Six people each built their own rather than adopt an existing one, which is the signature
of a scratch-your-own-itch category rather than a demand curve. Marketplace-wide, the median
extension has ~500 installs against a ~55K mean.

*The industry moved the other way.* CodeStream — the best-funded attempt at pulling project and
observability context into the editor — reaches end of life in November 2026, and its vendor's
stated replacement is not another panel but an MCP server feeding the same data to the coding
agent. Meanwhile the core loop is leaving the IDE for terminal-native agents. A panel optimizes
for a glance away from the terminal, in a workflow trending toward the terminal being the whole
surface.

*The pain is already solved here, twice.* The upstream dashboards exist because that method's
state lives in local markdown with no viewer at all; building one is the only way to see it.
Leanwheel's state lives in **GitHub milestones and issues**, which have several viewers already,
and in `/status`, which renders the same data plus the next command. The genuinely novel thing an
extension would add over `/status` is *"visible without spending a turn"* — and a status line
does that for a few hours of work instead of a permanent TypeScript codebase, second language,
marketplace listing, and VS Code API churn attached to a repo whose thesis is cutting ceremony.
It would also reintroduce the build → package → install → restart cycle the symlink-consumption
setup exists to avoid.

**What ships instead.** In order of value: (1) a status line rendering
`Epic 3 ▸ 5/8 ▸ 3.6 in-progress` from cached `gh` output — zero tokens, always visible, works in
a bare terminal and in the IDE's integrated terminal alike; (2) the data-gathering half of
`/status` promoted into `scripts/status.sh`, the same split DD-62 and `gh-track.sh` already make,
so a human can run it with no agent turn at all; (3) an on-demand HTML render of
`docs/metrics/flywheel-ledger.jsonl` at epic boundaries, if the charts are ever actually wanted.

**For the IDE glance specifically, configure the extension that already exists.** Microsoft's
GitHub Pull Requests and Issues extension has an Issues view whose `githubIssues.queries` setting
takes GitHub search syntax plus a `groupBy` array accepting `milestone` and `repository` — its
shipped default already groups by milestone. Epics-as-milestones and stories-as-issues therefore
render correctly with no code written, and the leanwheel status labels filter cleanly:

```jsonc
"githubIssues.queries": [
  { "label": "Epics & stories", "query": "is:open repo:${owner}/${repository}",
    "groupBy": ["milestone"] },
  { "label": "Ready for dev",   "query": "is:open label:ready-for-dev repo:${owner}/${repository}",
    "groupBy": ["milestone"] },
  { "label": "In progress",     "query": "is:open label:in-progress repo:${owner}/${repository}" },
  { "label": "In review",       "query": "is:open label:review repo:${owner}/${repository}" }
]
```

Its "Start working on issue" action also creates a branch from the issue and (via
`githubIssues.assignWhenWorking`) self-assigns — the manual half of the story kickoff that
`/dev-story` otherwise narrates.

**What would reverse this.** Measurable adoption of an existing dashboard extension in this
category; enough leanwheel users filing "how do I see status without burning a turn" that the
status line demonstrably doesn't answer it; or a shift to several concurrent agents/epics at once,
where the need becomes a cross-session fleet view — a different product from an epic/story panel,
and the one worth reconsidering from scratch.

---

### DD-70 — Evals RUN is a script, and the script is the CI seam
**Context.** `docs/evals/` was described as costing "zero tokens", and its *execution* did.
Collection did not: a model had to read every case block in `docs/evals/*.md` to gather the
cases and group them by identical `run:` command. That read grows with every story, so the
one gate designed to get cheaper as the project matured was quietly getting more expensive —
the same accretion `epic-archive` exists to stop, in a different file.

Separately, the regression net was reachable only from inside a Claude session. As an add-in,
leanwheel cannot ship a pipeline config: the project's CI could be GitHub Actions, Jenkins,
GitLab, or a pre-push hook, and guessing wrong is worse than not guessing.

**Decision.** `scripts/evals.sh` owns collection, batching, assertion and reporting. RUN is one
shell call whose cost does not scale with the case count, and skills **never** read
`docs/evals/*.md` to run the set. The script exits 0 green / 1 on regressions / 2 on usage, and
its last line *is* the RUN report other skills quote. Whatever the project uses for CI calls it;
leanwheel ships the contract, not the pipeline.

**Consequence.** The eval-case format now has a real parser, so it is a schema rather than a
convention — the script owns batching by identical `run:`, empty-output failure, README
exclusion, and the rule that a malformed case (`enabled: true` with no `run:`, an unparseable
`expect:`) is a **failure** and never a silent skip. Changing the case format means changing the
script. The Simulator-batching rule moved from prose the model had to honor into behavior it
cannot bypass.

### DD-71 — The per-file budget is measured in bytes, not lines
**Context.** SKILL.md files carried a 300-line ceiling. Measuring the repo showed line count and
token cost are close to uncorrelated across it: `epic-flywheel` sat at 263 lines and ~6,450
tokens — the most expensive file in the repo, and formally compliant — while `swift-audit` at
355 lines and ~3,816 tokens was carried as debt. A step-list skill wraps at 60 characters; a
table-and-prose skill runs to 200. Ranking by lines put the cheapest file in the penalty box
and cleared the most expensive one.

**Decision.** Budget in bytes: **20 KB** per `SKILL.md`, **4 KB** per `agents/*.md`. Check with
`find .claude/skills -name SKILL.md -size +20k`.

**Consequence.** The debt list changed membership, not just order — `dev-story` and both
`appstore-*` skills entered it, `swift-audit` and `setup` left. Two fixes apply and are not
interchangeable: branch-conditional bulk routes out to sibling reference files (nothing lost),
while conduct prose gets cut (Claude 5 guidance says carried-over verification instructions
cause over-verification, so some of it is not merely costly but counterproductive).

### DD-72 — Effort is pinned per subagent, never inherited
**Context.** Model routing had a cost ceiling — Opus, never Fable — but effort was left to
inherit the session default, on the reasoning that changing it busts the prompt cache. That
reasoning holds *within* a conversation and not across spawns: a subagent starts its own
conversation, so pinning its effort costs the orchestrator no cache at all. Meanwhile
inheritance was a hole straight through the ceiling — a `max`-effort session leaked `max` into
every phase, which is precisely what pinning the model was meant to prevent. On 5-series models
effort is the primary cost control and governs *all* output tokens, thinking and tool calls
alike.

**Decision.** Every phase-runner pins `effort:` in its agent def: creator `medium`, developer and
reviewer `high`, `lw-docs-sync` `low`. The developer is never stepped down to buy budget — lower
effort also means *fewer tool calls*, which is wrong for a phase whose job is to run gates; use
the model axis for cost, which is what it is for. (`effort` is inert on Haiku, which does not
support it; the pin is kept against a future re-tier.)

**Consequence.** Cost is now expressed on two independent axes with one ceiling each. The levels
are a starting point, not a result: Anthropic's guidance is to sweep effort against your own
evals rather than carry levels over, and `evals/` is where that sweep belongs.

