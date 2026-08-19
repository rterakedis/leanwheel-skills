---
name: epic-flywheel
description: Drive an entire epic to completion semi-autonomously — runs the per-story flywheel (create → dev → review) for every story with granular commits, then a single epic-boundary verification + manual-test-planning pass. Use when the user says "epic flywheel", "run the whole epic", "flywheel the epic", or "run epic {N} autonomously".
---

# Epic Flywheel Skill

**Goal:** Take a whole epic from "stories not started" to "all stories implemented, reviewed, and verified together" with minimal steering. The per-story automated gates (Build & Test, evals RUN, invariant verification) still stop the loop on a real compounding bug; the **manual / integration test pass is deferred to the epic boundary** (DD-30).

**Relationship to `/story-flywheel`:** epic-flywheel is the autonomous, epic-scoped layer above story-flywheel. It reuses the same three subagents and per-phase model routing (story-flywheel → **Subagent Delegation & Model Routing**; not duplicated here). What epic-flywheel adds: (1) commit-per-step so a bad story can be unraveled, (2) within-epic auto-advance on clean stories, (3) an **Epic Boundary Gate** that runs build+test+evals+invariants across the whole epic and **HALTs for help** on any failure, (4) continuous deferred-item re-homing, and (5) a deduplicated **rolled-up test plan** that first subtracts what automation already proves, then splits the remainder into simulator-runnable vs physical-device-required.

---

## Iron rules

1. **HALT, don't push forward.** A red Build & Test Gate, a failing eval, an unverifiable invariant, or a dev-story HALT stops the loop and asks the user for help. Never carry a broken story into the next one.
2. **Commit every step.** create → commit → dev → commit → review+patch → commit. The granular trail is what lets you `git bisect`/revert to the precise step that went wrong.
3. **Don't accumulate context.** The orchestrating thread holds only short structured reports from subagents — never full story files or source. The only LLM-heavy work this thread does itself is the one-time test-plan dedup at the epic boundary, over collected plan text only.
4. **Deferred means re-homed, not forgotten.** Every `[Defer]` finding gets a home (slotted as an AC or a remediation story) via the `deferred` skill, and the Epic Boundary Gate sweeps for any orphan.

---

## Activation

1. **Pick the epic.** Same discovery as story-flywheel (sort by epic number embedded in milestone *title*, not GitHub milestone ID; fall back to `docs/epics.md`). Accept `/epic-flywheel {N}` to force one. Announce: "Epic-flywheel for Epic {N}: {title}. {X} stories. I'll run them with per-story gates, commit each step, then do one verification + test-planning pass at the end."

2. **Delegation mode + model routing.** Identical to story-flywheel (→ **Subagent Delegation & Model Routing**): detect `swift_project`, prefer subagent-delegation mode (`lw-story-creator` / `lw-story-developer` / `lw-story-reviewer`), `model: sonnet` override on Phase 2 only when `swift_project = false` (Swift dev-story inherits the session model); inline on the session model only when subagents are unavailable.

3. **Detect the Apple platform set.** Set `apple_project = true` if `swift_project`. Read `docs/setup/manifest` / `docs/setup/swift/` and `docs/ux/EXPERIENCE.md` only enough to learn which platforms ship (iOS/iPadOS/macOS). This governs the simulator-vs-physical split at the boundary. Non-Apple projects get a generic "automated/local-runnable vs manual" split instead.

4. **Commit authorization (required for autonomy).** Ask once:
   > Epic-flywheel commits after each step (create / dev / review) so the trail is granular and unravel-able. Authorize automatic commits for this run? (yes / no — if no, I'll pause for you to commit at each step.)

   Detect the commit command: prefer `scripts/commit-push.sh "<msg>"` if it exists in the project, else plain `git add -A && git commit`. Push only if the project's script pushes (don't introduce pushing where the project doesn't).

5. **Autonomy level.** Default is **auto-advance within the epic**: any story whose per-story gates are fully green (no `UNRESOLVED`, PASS rubric, green Build & Test, evals pass, invariants verified) advances without a checkpoint. The loop still stops on red/HALT. Offer the stricter alternative:
   > Default: I auto-advance on clean stories and only stop for problems or the epic boundary. Prefer a checkpoint after *every* story instead? (auto / every-story)

---

## The Per-Story Loop

For each story in the epic, in story order. Spawn each phase as its subagent (cold start; it owns the heavy reading). The orchestrator captures only the structured report fields.

**"Spawn" = a literal Agent tool call** (`subagent_type` = `lw-story-creator` / `lw-story-developer` / `lw-story-reviewer` / `lw-docs-sync`), per story-flywheel → **Spawning a phase** — if a step ends with no Agent call in the transcript, the step did not run. Its **non-return rule** and PID/artifact wait loops apply here unchanged (DD-21): a report missing its required fields means the phase hasn't returned — resume the subagent via SendMessage, don't advance.

### GitHub tracking is orchestrator-owned (do not delegate-and-hope)

The orchestrator drives every issue transition itself with the deterministic script (DD-22); subagents are not relied on for this:

```
backlog → ready-for-dev → in-progress → review → done (+ closed)
```

At each transition point in the steps below, run one line — it adds the target label, strips every stale status label, and self-verifies:

```bash
bash scripts/gh-track.sh transition {issue#} {label}    # ready-for-dev|in-progress|review
bash scripts/gh-track.sh close {issue#} "Story {e}.{s} complete"   # final: done + close
```

Get `{issue#}` from the create-story report or `grep '^github_issue:' {story_file}`. If it's `0`/missing the issue was never created — run github-tracking **CREATE-ISSUE** first, don't silently skip. If the script is absent, fall back to the github-tracking TRANSITION/CLOSE-ISSUE ops. If `gh` is unavailable the script prints `skip: gh unavailable` and exits 0 — note that once in the boundary report rather than claiming issues were updated.

### Step 1 — Create Story → commit
Spawn `lw-story-creator` with `{epic}.{story}`. Capture `STORY FILE`, `EPIC CONTEXT`, `COMPLEXITY`, `CLARIFICATIONS NEEDED`, `PREREQUISITES`, `DESIGN GAP`.
- **Epic context gate (zero-token, orchestrator-owned):** run `[ -f docs/epics/epic-{N}-context.md ]`. The creator must have generated or reused it (report field `EPIC CONTEXT`). If the file is absent, re-spawn `lw-story-creator` with an explicit prompt to run create-story's **Generate Cache** section for Epic {N}, then re-check. Never advance to Step 2 or commit while the file is missing (DD-23).
- **Clarification Gate (the one mandatory human pause inside a story):** if the report lists *material* clarifications, surface them now and wait for answers; record them into the story file. One-default ambiguities are recorded as stated assumptions and do not pause.
- **Cross-story prerequisite check:** if `PREREQUISITES` names a runtime artifact owned by a *later* story in this or another epic, flag a sequencing risk now — the legitimate "not built yet" case belongs at story-design time, not as a fake bug later.
- **Track:** `gh-track.sh transition {issue#} ready-for-dev`.
- **Commit:** `story {epic}.{story}: create` (stages the story file + the epic context cache if generated/updated this step + any tracking/epics edits).

### Step 2 — Dev Story → commit
**Track first:** `gh-track.sh transition {issue#} in-progress` before spawning, so a long dev pass shows the right state. Then spawn `lw-story-developer` (`model: sonnet` only if `swift_project = false`; on Swift it inherits the session model) with the story file path. It runs the full dev-story workflow: implementation, **Build & Test Gate** (verify by running), **evals RUN** (if `docs/evals/`), invariant + design verification, and the inline review. Capture `STATUS`, `BUILD & TEST`, `BUILD/TEST ITERATIONS`, `EVALS`, `FINDINGS`, `INVARIANTS`, `INFRA TOUCHED`, `UNRESOLVED`, `TESTING PLAN`.
- **On HALT or red gate:** stop the loop. Report which story and why; do **not** commit a red story. Resume with `/epic-flywheel {N}` after the blocker is fixed.
- **Operational doc sync (cheap, orchestrator-owned):** the developer does not run docs-sync (DD-24). If `INFRA TOUCHED: yes`, spawn **`lw-docs-sync`** (Haiku) with the story path and op `OPERATIONAL`; capture `DOCS UPDATED`. Skip the spawn when `INFRA TOUCHED: no`. The doc edits land in the dev commit below.
- **Track:** on green, `gh-track.sh transition {issue#} review`.
- **Commit (only if gate green):** `story {epic}.{story}: dev` (includes any docs-sync edits).
- **Testing-plan shape gate (zero-token):** the report's `TESTING PLAN` must carry both sub-fields, `AUTOMATED:` and `MANUAL:` (dev-story → *Testing Plan (required report field)*). Missing either → non-return: resume the subagent via SendMessage for the complete field; do not stash a half plan.
- **Stash the TESTING PLAN** for the boundary roll-up — both sub-fields, text only. Append one block per story to a scratch list `docs/epics/.epic-{N}-test-plans.md`:
  ```
  ## {epic}.{story} — {title}
  AUTOMATED: {names}
  MANUAL: {tagged lines}
  ```
  The `AUTOMATED` names are the subtract list the boundary greps against.

### Step 3 — Code Review + patch → commit
Per story-flywheel's Phase 3 economy and its **blast-radius trigger set** (not duplicated here): the developer subagent already ran the inline review.
- **Clean report (no `UNRESOLVED`, PASS gate, not security-sensitive) and no blast-radius trigger:** skip a separate reviewer — carry Phase 2 findings forward.
- **Otherwise:** spawn `lw-story-reviewer` for an independent adversarial pass. It emits the SCORE rubric line, auto-patches `patch` findings, applies `fix-now` findings within code-review's Triage ceiling (recorded in Review Findings, not logged as deferred), logs `defer` via the `deferred` skill (re-homing each — slot as AC or remediation story), and **re-verifies green**. `decision-needed` findings surface to the user.
- **Deferred re-homing check:** confirm every `[Defer]` from this story landed in `docs/deferred-items.md` with a `Scheduled As` target. An orphan is a loop bug — fix before advancing.
- **Track:** on green, `gh-track.sh close {issue#} "Story {epic}.{story} complete"` (applies `done` + closes — milestone progress ticks up here).
- **Commit (only if green after patches):** `story {epic}.{story}: review+patch`. If patches couldn't resolve, leave status `in-progress`, don't commit, HALT.

### Step 4 — Advance or checkpoint
- **auto mode (default):** if the story is fully green, append the per-story roll-up via `scripts/ledger.sh story-flywheel …` (per story-flywheel → Observability — written every story, silent advance included) and advance silently to the next story. If anything is non-green, stop.
- **every-story mode:** present the standard story-flywheel Phase-4 checkpoint and wait.
- When the last story in the epic finishes → **Epic Boundary Gate**.

---

## Epic Boundary Gate

All stories implemented, reviewed, and individually green. Now verify the epic *as a whole* and prepare the human test pass. **Any failure here HALTs and asks for help — do not start the next epic.**

### 1. Epic Build & Test Gate (whole project)
Run a full, unfiltered build + test — not story-scoped:
- Apple: `xcodebuild -quiet … build test` (and `swift build -q && swift test -q` for SPM targets).
- Web: the project's quiet build + test scripts.
Use the project CLAUDE.md `## Quiet commands` invocations when present; always `tee` the full log to `.leanwheel/logs/` and keep only the tail in context (dev-story → Build & Test Gate).
- Else: the documented project command.
Red build / any failing test → **HALT**: report the failing target/test output and ask the user how to proceed.

### 2. Evals RUN — full cumulative set
Invoke the `evals` RUN op over the entire `docs/evals/` (every epic, not just this one) — the cumulative `command` regression net. A failing case → **HALT** with the failing case listed.

### 3. Invariant verification sweep
Collect the `### Invariant Verification` blocks recorded by dev-story across this epic's stories (read the short blocks, not full files). Any invariant left `[ ] UNVERIFIED` (no test, no cited enforcing `file:line`) → **HALT** and surface it for the user (DD-14).

### 4. Deferred sweep
Two-pass, mirroring `/retrospective`:
- **Pass 1:** scan this epic's story files for `[Defer]` entries not present in `docs/deferred-items.md`; LOG-AND-SCHEDULE any orphan so it gets a home.
- **Pass 2:** verify every logged deferred item has a non-empty `Scheduled As` pointing at open work. Report the count re-homed.

### 4a. CLAUDE.md budget check (zero-token, non-blocking)
`wc -l CLAUDE.md` > 300 → report as a finding in the boundary report: root CLAUDE.md is over the 300-line budget; demote (T2→T1) or move to a nested CLAUDE.md rather than append (DD-54; `/retrospective`'s CLAUDE.md tier-audit step).

### 4b. Tracking reconcile (safety net)
Reconcile the whole epic's issues against story frontmatter:
```bash
bash scripts/gh-track.sh sync "<story-glob>"            # dry-run diff
bash scripts/gh-track.sh sync "<story-glob>" --apply    # if the diff is non-empty
```
A clean diff (`0 to-change`) is the proof every issue landed in the right state. Report the count fixed in the boundary report. If the project predates the script, call the github-tracking SYNC op instead.

### 4c. Architecture promotion (canonical-doc sync, cheap)
Call the Agent tool with `subagent_type: "lw-docs-sync"` (Haiku) and a prompt naming op `PROMOTE` and Epic {N} (fallback: execute the docs-sync **PROMOTE** op inline if subagents are unavailable). It harvests project-canonical learnings from `docs/epics/epic-{N}-context.md` and appends the durable ones to `docs/architecture.md` (idempotent; also `docs/sql/` / `docs/maintainer/` when present) — see DD-58. Zero-token when the context file has nothing canonical; never touches `docs/setup/*` guidance. Report the count promoted in the boundary report.

### 5. Rolled-up, deduplicated, **subtracted** Test Plan (the manual pass)
Read the accumulated `docs/epics/.epic-{N}-test-plans.md` scratch list (collected plan text only — no source). Then:

0. **Every flow opens with a "Starting state" prerequisites block** before step 1 — the required data and settings state the tester must have in place. Steps then follow real usage order, not story order.
   - **Setup commands are part of the starting state.** When reaching the state needs a terminal command (`scripts/sim.sh launch …`, `xcrun simctl …`, a dev-server or seed script), print the exact command in the block, carrying every flag the app needs to honour it — a launch argument the app only reads in combination with another (e.g. an entitlement override applied only under `--uitest`/`--seed`) must appear with its companions; a bare flag the app silently ignores produces a false finding. When unsure, grep the launch-argument handler (testability foundation) rather than guessing.
1. **Deduplicate & merge** the `MANUAL` items across stories into end-to-end flows (e.g. five stories each touching the cart → one "complete a purchase" flow plus the per-story edge cases that aren't covered by the flow).
2. **Enumerate edge cases** the individual story plans listed, deduped against the flows.
3. **Subtract what is already automated (mandatory, zero-token grep + one judgment pass; DD-31).** For each candidate human step:
   - Collect the union of the stashed `AUTOMATED` names, then grep the project's **UI-test flows**, **unit test target**, and **`docs/evals/epic-*.md`** (cumulative, every epic) for the step's surface or assertion — identifiers, flow/suite/case names, the string asserted on.
   - **Covered** → remove it from the checkbox list. It is listed by name in the flow's `Automated — do not re-test:` line instead.
   - **Not covered** → it stays, unless a test could clearly pin it — then say so in `## Notes` as an automation gap (`/e2e-tests` candidate), and keep it as a human step for this pass only.
   - Record `{s}` = the number of candidate steps subtracted and `{g}` = the number of automation gaps flagged; both go in the boundary report.

   > **Rule: a test plan step that restates an existing automated assertion is a defect of this step.** Section A may contain only (a) assertions with no flow/eval coverage and (b) visual/layout-judgment passes — design-eye, Dynamic Type, dark mode, copy tone. Everything else is either already pinned (subtract it) or should be (flag it).
4. **Classify every remaining test** by where it can run:
   - **Simulator / local-runnable** — anything exercisable in the iOS/iPadOS/macOS simulator (or, for web, a local dev server / headless browser). UI flows, navigation, state, layout, Dynamic Type, light/dark, most logic.
   - **Physical-device-required** — needs real hardware or a paid/org capability: camera & photo capture, real push notifications (APNs on device), Face ID / Touch ID, background location, Bluetooth / NFC / HealthKit sensors, real network conditions, thermal/perf, StoreKit on-device purchase, anything gated behind an **org-based developer account / provisioning** the user doesn't yet have. The stashed `MANUAL` tags (`device-only`, `sandbox-only`) route here directly.

Write the result to `docs/epics/epic-{N}-test-plan.md`:

````markdown
# Epic {N} — {title}: Test Plan
_Rolled up from {X} story plans on {date}: {a} human steps after subtracting {s} already-automated, {b} physical-device._
_To log a finding: add an **indented** plain bullet (`-` or `*`, no checkbox) directly under the relevant step — e.g. `  - shows wrong total`. Leave the `- [ ]` step lines as checkboxes (check them off as you pass them). Then run `/harvest-findings {N}` to capture and schedule the findings._
_If a step turns out to be already covered by a passing test, note it as a finding too (`  - already automated: {flow}`) — it is a plan defect the retro counts._

## A. Simulator / local-runnable (do now)
### Flow: {name}
**Automated — do not re-test:** {flow/suite/eval names that already prove this flow, e.g. `UpgradeSheetFlow`, `CustomerLimitServiceTests`, `E12-03`}
**Starting state:** {required data, settings state — everything that must be true before step 1}
```bash
scripts/sim.sh launch --uitest --seed heavy --route {route}   # every flag the app needs; bare flags are ignored
```
- [ ] {step the automation cannot see} → {expected} [visual-judgment | setup-unreachable]
### Edge cases
- [ ] {case} → {expected}

## B. Physical-device pass (DEFERRED — requires org developer account)
> These cannot run on the current developer account / simulator. Batch them for the
> physical-device test session once the org-based account and provisioning are in place.
- [ ] {test} — requires: {camera | APNs push | Face ID | …}

## Notes
- {anything ambiguous the tester should confirm}
- Automation gaps (should be pinned, `/e2e-tests` candidates): {list or "none"}
````

The `Automated — do not re-test:` line is mandatory on every section-A flow (write `none` only when the flow genuinely has no coverage — and then expect the flow to be an automation gap).

Also **append section B's items to a persistent cross-epic backlog** `docs/testing/physical-device-backlog.md` (create if absent), tagged with the epic. Delete the `.epic-{N}-test-plans.md` scratch file after writing.

### 5b. Squash-merge to main — Apple / manual-test epics (conditional)

**Only when the manual test pass needs a build the user drives** (`apple_project = true`, or any epic whose test plan must be built/run outside the agent — e.g. Xcode/TestFlight, a native desktop app). Skip for web/library epics where the agent runs the tests itself.

If the project's `CLAUDE.md` prescribes merge-at-boundary (look for an "Epic-boundary merge" rule), **do it now**, after gates 1–4c are green and the test plan (step 5) is written: squash-merge the epic branch to `main`, then remove the worktree (rationale: DD-25).

```bash
gh pr create --fill --base main --head feature/<epic-slug>
gh pr merge --squash --delete-branch                       # run from the PRIMARY tree, not the worktree
git -C <primary> worktree remove <worktree-path>; git -C <primary> pull --ff-only origin main
```
Note: `gh pr merge` may fail its local checkout step if run from inside the worktree — the remote merge still lands; finish the worktree-remove + `pull` from the primary tree. If the project's `CLAUDE.md` has no merge-at-boundary rule, do NOT merge — leave the branch open and only offer the PR in the boundary report.

### 6. Boundary report
```
─────────────────────────────────────────────
EPIC {N} COMPLETE & VERIFIED — {X} stories
─────────────────────────────────────────────
Build & Test (whole project): {green | HALTED}
Evals (cumulative): {p}/{t} command pass
Invariants: {v}/{t} verified
Deferred re-homed this epic: {n} (0 orphans)
Architecture learnings promoted: {n} → docs/architecture.md
Test plan: docs/epics/epic-{N}-test-plan.md
  {a} human steps (after subtracting {s} already-automated), {b} physical-device
  • Simulator/local (section A): {a}  ← run these now; each flow lists what NOT to re-test
  • Physical-device (section B): {b}  ← deferred to org-account pass
  • Automation gaps flagged: {g}  ← /e2e-tests candidates
Commits this epic: {count} (granular: create/dev/review per story)
─────────────────────────────────────────────
RECOMMENDED FLOW:
  1. Work through the simulator/local test plan above, recording findings inline
     under each scenario in docs/epics/epic-{N}-test-plan.md.
  2. → Run /harvest-findings {N} to capture those findings, schedule the in-scope
       ones as story {N}.{last+1}, and reset the plan for re-test.
  3. → Then run /retrospective for Epic {N} to capture learnings
       and update conventions BEFORE starting Epic {N+1}. It also condenses
       Epic {N} in docs/epics.md (epic-archive CONDENSE) — story detail
       collapses to a summary row; the full spec stays in each story file.

Next:
  • "test"      — walk me through the simulator test plan now
  • "harvest"   — run /harvest-findings {N} (do this after testing, before retro)
  • "retro"     — run the retrospective for Epic {N} (do this after harvesting)
  • "continue"  — skip retro and start epic-flywheel on Epic {N+1}
  • "stop"      — end here
─────────────────────────────────────────────
```
Append the epic-level roll-up via `scripts/ledger.sh epic-flywheel --story epic-{N} --models … --build-test … --evals …`. Wait for the user — the boundary is always a human gate.

**Retrospective reminder is mandatory.** The Epic Boundary Gate always surfaces the retrospective prompt — never close an epic silently.

**`/retrospective` is human-in-the-loop even here.** It asks retrospective's `## Seven Questions` one at a time and waits for answers; autonomously generating the retro from git history is forbidden. If the user picks `"continue"` (skip retro), confirm once: "Starting Epic {N+1} without a retrospective for Epic {N} — the learnings/conventions from this epic won't be captured. Proceed?" Honor their choice, but make the skip explicit. If the user runs `"test"` first, then returns, re-surface the retrospective reminder before advancing to the next epic.

**Last epic of the phase.** If no later epic remains in `docs/epics.md`, add one more line to the recommended flow after step 3: `4. → Optionally /epic-archive cut-release {version} to archive this phase's epics.md and seed a fresh one for the next phase.` An offer only — never cut a release automatically.

---

## Exit Conditions

- **All epics complete:** every milestone closed / every story done → final "ALL EPICS COMPLETE" message; suggest `/retrospective` and `/status`.
- **HALT (gate failure or dev-story blocker):** loop stops, reports the exact story/step and the failing output, and asks for help. Resume with `/epic-flywheel {N}` (or `/epic-flywheel {epic}.{story}` to re-enter at a story). The granular commits mean the user can `git reset`/revert to the last good step.
- **User "stop":** graceful exit; report stories remaining and the resume command.

## Resuming

`/epic-flywheel` with no arg detects in-flight state from GitHub labels / `Status:` fields (same rules as story-flywheel): `in-progress` → resume at Step 2; `review` → resume at Step 3; otherwise start at the first incomplete story. If all stories are done but no `epic-{N}-test-plan.md` exists, resume directly at the Epic Boundary Gate.

---

## Notes

- **Token posture:** every per-epic gate is zero-token (build/test/evals are shell commands; the invariant and deferred sweeps read short recorded blocks). The only model-heavy step is the once-per-epic test-plan dedup + subtract, bounded over plan text plus grep hits.
- **Why subtract before writing the plan:** DD-31. **Why defer manual testing to the boundary:** DD-30. **Why commit-per-step:** a bisectable, unravel-able history instead of one giant squash.
