---
name: epic-flywheel
description: Drive an entire epic to completion semi-autonomously — runs the per-story flywheel (create → dev → review) for every story with granular commits, then a single epic-boundary verification + manual-test-planning pass. Use when the user says "epic flywheel", "run the whole epic", "flywheel the epic", or "run epic {N} autonomously".
---

# Epic Flywheel Skill

**Goal:** Take a whole epic from "stories not started" to "all stories implemented, reviewed, and verified together" with minimal steering. The per-story automated gates (Build & Test, evals RUN, invariant verification) still stop the loop on a *real* (compounding) bug, but the **manual / integration test pass is deferred to the epic boundary** — the point at which every story's pieces are in place, so tapping through a flow no longer trips over "feature X isn't built yet" (which is just a later story, not a bug).

**Relationship to `/story-flywheel`:** epic-flywheel is the autonomous, epic-scoped layer *above* story-flywheel. It reuses the same three subagents and the same per-phase model routing (see story-flywheel's **Subagent Delegation & Model Routing** — do not duplicate that table here; read it). What epic-flywheel adds: (1) granular commit-per-step so a bad story can be unraveled, (2) within-epic auto-advance on clean stories, (3) a real **Epic Boundary Gate** that runs build+test+evals+invariants across the whole epic and **HALTs for help** on any failure, (4) continuous deferred-item re-homing, and (5) a deduplicated, LLM-verified **rolled-up test plan** split into simulator-runnable vs physical-device-required.

---

## Iron rules

1. **HALT, don't push forward.** A red Build & Test Gate, a failing eval, an unverifiable invariant, or a dev-story HALT stops the loop and asks the user for help. Never carry a broken story into the next one — that is the exact failure mode (bugs compounding across stories) this skill exists to prevent.
2. **Commit every step.** create → commit → dev → commit → review+patch → commit. The granular trail is what lets you `git bisect`/revert to the precise step where something went wrong instead of unwinding a whole epic.
3. **Don't accumulate context.** The orchestrating thread holds only short structured reports from subagents — never full story files or source. Heavy reading happens inside throwaway subagent windows that exit and free their context. The only LLM-heavy work this thread does itself is the one-time test-plan dedup at the epic boundary, over collected plan *text only*.
4. **Deferred means re-homed, not forgotten.** Every `[Defer]` finding gets a home (slotted as an AC or a remediation story) via the `deferred` skill, and the Epic Boundary Gate sweeps for any orphan.

---

## Activation

1. **Pick the epic.** Same discovery as story-flywheel (sort by epic number embedded in milestone *title*, not GitHub milestone ID; fall back to `docs/epics.md`). Accept `/epic-flywheel {N}` to force one. Announce: "Epic-flywheel for Epic {N}: {title}. {X} stories. I'll run them with per-story gates, commit each step, then do one verification + test-planning pass at the end."

2. **Delegation mode + model routing.** Identical to story-flywheel: set `swift_project = true` if `docs/setup/swift/` exists OR an `.xcodeproj`/`.xcworkspace`/`Package.swift` is present. Prefer subagent-delegation mode (spawn `lw-story-creator` / `lw-story-developer` / `lw-story-reviewer`); pass `model: opus` only for Phase 2 (dev-story) on Swift. Fall back to inline + manual MODEL SWITCH GATE only when subagents are unavailable.

3. **Detect the Apple platform set.** Set `apple_project = true` if `swift_project`. Read `docs/setup/manifest` / `docs/setup/swift/` and `docs/ux/EXPERIENCE.md` only enough to learn which platforms ship (iOS/iPadOS/macOS). This governs the simulator-vs-physical split at the boundary. Non-Apple projects get a generic "automated/local-runnable vs manual" split instead.

4. **Commit authorization (required for autonomy).** epic-flywheel commits at every step, so it must be pre-authorized. Ask once:
   > Epic-flywheel commits after each step (create / dev / review) so the trail is granular and unravel-able. Authorize automatic commits for this run? (yes / no — if no, I'll pause for you to commit at each step.)

   Detect the commit command: prefer `scripts/commit-push.sh "<msg>"` if it exists in the project, else plain `git add -A && git commit`. Push only if the project's script pushes (don't introduce pushing where the project doesn't).

5. **Autonomy level.** Default for epic-flywheel is **auto-advance within the epic**: any story whose per-story gates are fully green (no `UNRESOLVED`, PASS rubric, green Build & Test, evals pass, invariants verified) advances without a checkpoint. The loop **always** stops on red/HALT. Offer the stricter alternative:
   > Default: I auto-advance on clean stories and only stop for problems or the epic boundary. Prefer a checkpoint after *every* story instead? (auto / every-story)

---

## The Per-Story Loop

For each story in the epic, in story order. Spawn each phase as its subagent (cold start; it owns the heavy reading). The orchestrator captures only the structured report fields.

### GitHub tracking is orchestrator-owned (do not delegate-and-hope)

A cold subagent does **not** reliably run the issue transitions, and nothing verifies it did — that is how issues drift (stuck on `ready-for-dev`, a stale `backlog` left beside a new label, dev'd stories never closed). epic-flywheel already gates every commit, so it knows the exact moment each phase ends and **drives the transition itself** using the deterministic script:

```
backlog → ready-for-dev → in-progress → review → done (+ closed)
```

At each transition point in the steps below, run one line — it adds the target label, **strips every stale status label**, and self-verifies:

```bash
bash scripts/gh-track.sh transition {issue#} {label}    # ready-for-dev|in-progress|review
bash scripts/gh-track.sh close {issue#} "Story {e}.{s} complete"   # final: done + close
```

Get `{issue#}` from the create-story report or `grep '^github_issue:' {story_file}`. If it's `0`/missing the issue was never created — run github-tracking **CREATE-ISSUE** first, don't silently skip. If the script is absent, fall back to the github-tracking TRANSITION/CLOSE-ISSUE ops. If `gh` is unavailable the script prints `skip: gh unavailable` and exits 0 — note that once in the boundary report rather than claiming issues were updated.

### Step 1 — Create Story → commit
Spawn `lw-story-creator` with `{epic}.{story}`. Capture `STORY FILE`, `COMPLEXITY`, `CLARIFICATIONS NEEDED`, `PREREQUISITES`, `DESIGN GAP`.
- **Clarification Gate (the one mandatory human pause inside a story):** if the report lists *material* clarifications, surface them now and wait for answers; record them into the story file. One-default ambiguities are recorded as stated assumptions and do **not** pause.
- **Cross-story prerequisite check:** if `PREREQUISITES` names a runtime artifact owned by a *later* story in this or another epic, flag a sequencing risk — this is the legitimate "not built yet" case and must be handled at story-design time, not discovered as a fake bug later.
- **Track:** `gh-track.sh transition {issue#} ready-for-dev`.
- **Commit:** `story {epic}.{story}: create` (stages the story file + any tracking/epics edits).

### Step 2 — Dev Story → commit
**Track first:** `gh-track.sh transition {issue#} in-progress` before spawning, so a long dev pass shows the right state. Then spawn `lw-story-developer` (model `opus` only if `swift_project`) with the story file path. It runs the full dev-story workflow: implementation, **Build & Test Gate** (verify by running), **evals RUN** (if `docs/evals/`), invariant + design verification, and the inline review. Capture `STATUS`, `BUILD & TEST`, `BUILD/TEST ITERATIONS`, `EVALS`, `FINDINGS`, `INVARIANTS`, `INFRA TOUCHED`, `UNRESOLVED`, `TESTING PLAN`.
- **On HALT or red gate:** stop the loop. Report which story and why; do **not** commit a red story. Resume with `/epic-flywheel {N}` after the blocker is fixed.
- **Operational doc sync (cheap, orchestrator-owned):** the developer does **not** run docs-sync (it would land on the dev model — Opus on Swift). If `INFRA TOUCHED: yes`, spawn **`lw-docs-sync`** (Haiku) with the story path and op `OPERATIONAL`; capture `DOCS UPDATED`. Skip the spawn when `INFRA TOUCHED: no`. The doc edits land in the dev commit below.
- **Track:** on green, `gh-track.sh transition {issue#} review`.
- **Commit (only if gate green):** `story {epic}.{story}: dev` (includes any docs-sync edits).
- **Stash the TESTING PLAN** for the boundary roll-up (keep just the text — append it to a scratch list `docs/epics/.epic-{N}-test-plans.md`, one block per story, so the orchestrator never has to hold all plans in context at once).

### Step 3 — Code Review + patch → commit
Per story-flywheel's Phase 3 economy: the developer subagent already ran the inline review.
- **Clean report (no `UNRESOLVED`, PASS gate, not security-sensitive):** skip a separate reviewer — carry Phase 2 findings forward. Saves a full review's tokens.
- **Otherwise:** spawn `lw-story-reviewer` for an independent adversarial pass. It emits the SCORE rubric line, auto-patches `patch` findings, logs `defer` via the `deferred` skill (re-homing each — slot as AC or remediation story), and **re-verifies green**. `decision-needed` findings surface to the user.
- **Deferred re-homing check:** confirm every `[Defer]` from this story landed in `docs/deferred-items.md` with a `Scheduled As` target. An orphan is a loop bug — fix before advancing.
- **Track:** on green, `gh-track.sh close {issue#} "Story {epic}.{story} complete"` (applies `done` + closes — milestone progress ticks up here).
- **Commit (only if green after patches):** `story {epic}.{story}: review+patch`. If patches couldn't resolve, leave status `in-progress`, don't commit, HALT.

### Step 4 — Advance or checkpoint
- **auto mode (default):** if the story is fully green, append the per-story ledger line (`docs/metrics/flywheel-ledger.jsonl` if present) and advance silently to the next story. If anything is non-green, stop (never auto-advance over red).
- **every-story mode:** present the standard story-flywheel Phase-4 checkpoint and wait.
- When the last story in the epic finishes → **Epic Boundary Gate**.

---

## Epic Boundary Gate

All stories implemented, reviewed, and individually green. Now verify the epic *as a whole* and prepare the human test pass. **Any failure here HALTs and asks for help — do not start the next epic.**

### 1. Epic Build & Test Gate (whole project)
Run a full, unfiltered build + test — not story-scoped:
- Apple: `xcodebuild … build test` (and `swift build && swift test` for SPM targets).
- Web: `npm run build && npm test`.
- Else: the documented project command.
Red build / any failing test → **HALT**: report the failing target/test output and ask the user how to proceed. This catches integration breakage that per-story filtered runs can miss.

### 2. Evals RUN — full cumulative set
Invoke the `evals` RUN op over the **entire** `docs/evals/` (every epic, not just this one) — the cumulative `command` regression net. A failing case means a later story silently reverted earlier behavior. Treat exactly like a red build → **HALT** with the failing case listed.

### 3. Invariant verification sweep
Collect the `### Invariant Verification` blocks recorded by dev-story across this epic's stories (read the short blocks, not full files). Any invariant left `[ ] UNVERIFIED` (no test, no cited enforcing `file:line`) → **HALT**: an unverified invariant at epic close is a known gap, surface it for the user rather than asserting "it holds."

### 4. Deferred sweep
Two-pass, mirroring `/retrospective`:
- **Pass 1:** scan this epic's story files for `[Defer]` entries not present in `docs/deferred-items.md`; LOG-AND-SCHEDULE any orphan so it gets a home.
- **Pass 2:** verify every logged deferred item has a non-empty `Scheduled As` pointing at open work. Report the count re-homed; nothing is left to rot.

### 4b. Tracking reconcile (safety net)
Even with orchestrator-owned transitions, reconcile the whole epic's issues against story frontmatter so nothing is left drifted:
```bash
bash scripts/gh-track.sh sync "<story-glob>"            # dry-run diff
bash scripts/gh-track.sh sync "<story-glob>" --apply    # if the diff is non-empty
```
A clean diff (`0 to-change`) is the proof every issue landed in the right state. Report the count fixed in the boundary report. (If the project predates the script, call the github-tracking SYNC op instead.)

### 4c. Architecture promotion (canonical-doc sync, cheap)
Spawn **`lw-docs-sync`** (Haiku) with op `PROMOTE` and Epic {N} (fallback: execute the docs-sync **PROMOTE** op inline if subagents are unavailable). It harvests project-canonical learnings (schema realities, new/changed services & integrations, cross-cutting invariants, architectural decisions) from `docs/epics/epic-{N}-context.md` and appends the durable ones to `docs/architecture.md` (idempotent; also `docs/sql/` / `docs/maintainer/` when present) — so the next epic plans against live docs, not a stale architecture. Zero-token when the context file has nothing canonical (pure-refactor epics often don't); never touches `docs/setup/*` guidance. Report the count promoted in the boundary report.

### 5. Rolled-up, deduplicated Test Plan (the manual pass)
This is the payoff of deferring manual testing to here. Read the accumulated `docs/epics/.epic-{N}-test-plans.md` scratch list (collected plan text only — no source). Then, in a **single LLM pass**:
1. **Deduplicate & merge** overlapping steps across stories into end-to-end flows (e.g. five stories each touching the cart → one "complete a purchase" flow plus the per-story edge cases that aren't covered by the flow).
2. **Enumerate edge cases** the individual story plans listed, deduped against the flows.
3. **Classify every test** by where it can run:
   - **Simulator / local-runnable** — anything exercisable in the iOS/iPadOS/macOS simulator (or, for web, a local dev server / headless browser). UI flows, navigation, state, layout, Dynamic Type, light/dark, most logic.
   - **Physical-device-required** — needs real hardware or a paid/org capability: camera & photo capture, real push notifications (APNs on device), Face ID / Touch ID, background location, Bluetooth / NFC / HealthKit sensors, real network conditions, thermal/perf, StoreKit on-device purchase, anything gated behind an **org-based developer account / provisioning** the user doesn't yet have.

Write the result to `docs/epics/epic-{N}-test-plan.md`:

```markdown
# Epic {N} — {title}: Test Plan
_Rolled up and deduplicated from {X} story plans on {date}._
_To log a finding: add an **indented** plain bullet (`-` or `*`, no checkbox) directly under the relevant step — e.g. `  - shows wrong total`. Leave the `- [ ]` step lines as checkboxes (check them off as you pass them). Then run `/harvest-findings {N}` to capture and schedule the findings._

## A. Simulator / local-runnable (do now)
### Flow: {name}
- [ ] {step} → {expected}
### Edge cases
- [ ] {case} → {expected}

## B. Physical-device pass (DEFERRED — requires org developer account)
> These cannot run on the current developer account / simulator. Batch them for the
> physical-device test session once the org-based account and provisioning are in place.
- [ ] {test} — requires: {camera | APNs push | Face ID | …}

## Notes
- {anything ambiguous the tester should confirm}
```

Also **append section B's items to a persistent cross-epic backlog** `docs/testing/physical-device-backlog.md` (create if absent), tagged with the epic — so when the org account lands the user has one consolidated physical-test checklist instead of hunting through per-epic plans. Delete the `.epic-{N}-test-plans.md` scratch file after writing.

### 5b. Squash-merge to main — Apple / manual-test epics (conditional)

**Only when the manual test pass needs a build the user drives** (`apple_project = true`, or any epic whose test plan must be built/run outside the agent — e.g. Xcode/TestFlight, a native desktop app). Skip for web/library epics where the agent runs the tests itself.

If the project's `CLAUDE.md` prescribes merge-at-boundary (look for an "Epic-boundary merge" rule), **do it now**, after gates 1–4c are green and the test plan (step 5) is written: squash-merge the epic branch to `main`, then remove the worktree. Rationale — manual-test findings become a **new remediation story** (`{N}.{last+1}`) via `/harvest-findings`, so nothing rides the epic PR regardless of when the user tests; merging first puts the full app **and** `docs/epics/epic-{N}-test-plan.md` on `main`, where the user builds it directly and the editor/file-browser can open the test plan for inline findings.

```bash
gh pr create --fill --base main --head feature/<epic-slug>
gh pr merge --squash --delete-branch                       # run from the PRIMARY tree, not the worktree
git -C <primary> worktree remove <worktree-path>; git -C <primary> pull --ff-only origin main
```
Note: `gh pr merge` may fail its local checkout step if run from inside the worktree (main is checked out in the primary tree) — the remote merge still lands; finish the worktree-remove + `pull` from the primary tree. If the project's `CLAUDE.md` has **no** merge-at-boundary rule, do NOT merge — leave the branch open and only **offer** the PR in the boundary report (legacy behavior).

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
  • Simulator/local tests: {a}  ← run these now
  • Physical-device tests: {b}  ← deferred to org-account pass
Commits this epic: {count} (granular: create/dev/review per story)
─────────────────────────────────────────────
RECOMMENDED FLOW:
  1. Work through the simulator/local test plan above, recording findings inline
     under each scenario in docs/epics/epic-{N}-test-plan.md.
  2. → Run /harvest-findings {N} to capture those findings, schedule the in-scope
       ones as story {N}.{last+1}, and reset the plan for re-test.
  3. → Then run /retrospective for Epic {N} to capture learnings
       and update conventions BEFORE starting Epic {N+1}.

Next:
  • "test"      — walk me through the simulator test plan now
  • "harvest"   — run /harvest-findings {N} (do this after testing, before retro)
  • "retro"     — run the retrospective for Epic {N} (do this after harvesting)
  • "continue"  — skip retro and start epic-flywheel on Epic {N+1}
  • "stop"      — end here
─────────────────────────────────────────────
```
Append the epic-level ledger roll-up. Wait for the user — the boundary is always a human gate (it's where *they* do the manual testing).

**Retrospective reminder is mandatory.** The Epic Boundary Gate must always surface the retrospective prompt — never close an epic silently. If the user picks `"continue"` (skip retro), confirm once: "Starting Epic {N+1} without a retrospective for Epic {N} — the learnings/conventions from this epic won't be captured. Proceed?" Honor their choice, but make the skip explicit. If the user runs `"test"` first, then returns, re-surface the retrospective reminder before advancing to the next epic.

---

## Exit Conditions

- **All epics complete:** every milestone closed / every story done → final "ALL EPICS COMPLETE" message; suggest `/retrospective` and `/status`.
- **HALT (gate failure or dev-story blocker):** loop stops, reports the exact story/step and the failing output, and asks for help. Resume with `/epic-flywheel {N}` (or `/epic-flywheel {epic}.{story}` to re-enter at a story). The granular commits mean the user can `git reset`/revert to the last good step.
- **User "stop":** graceful exit; report stories remaining and the resume command.

## Resuming

`/epic-flywheel` with no arg detects in-flight state from GitHub labels / `Status:` fields (same rules as story-flywheel): `in-progress` → resume at Step 2; `review` → resume at Step 3; otherwise start at the first incomplete story. If all stories are done but no `epic-{N}-test-plan.md` exists, resume directly at the Epic Boundary Gate.

---

## Notes

- **Token posture (Pro plan):** every per-epic gate is zero-token (build/test/evals are shell commands; the invariant and deferred sweeps read short recorded blocks). The only model-heavy step is the once-per-epic test-plan dedup — bounded, over plan text only, and it replaces the far more expensive habit of re-testing manually after every story. Context isolation via subagents keeps the orchestrator thread small across a whole epic.
- **Why commit-per-step:** the user's stated goal — "see where things go wrong if we have to unravel it." Three commits per story turn an epic into a precise, bisectable history instead of one giant squash.
- **Why defer manual testing to the boundary:** within an epic, stories are interdependent; tapping through after story 2 of 6 surfaces "bugs" that are just stories 3–6 not built yet (false positives). The automated per-story gates still catch *real* compounding bugs immediately; only the human integration pass waits for the full picture.
