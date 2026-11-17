---
name: epic-flywheel
description: Drive an entire epic to completion semi-autonomously — runs the per-story flywheel (create → dev → review) for every story with granular commits, then a single epic-boundary verification + manual-test-planning pass. Use when the user says "epic flywheel", "run the whole epic", "flywheel the epic", or "run epic {N} autonomously".
---

# Epic Flywheel Skill

**Goal:** Take a whole epic from "stories not started" to "all stories implemented, reviewed, and verified together" with minimal steering. The per-story automated gates (Build & Test, evals RUN, invariant verification) still stop the loop on a real compounding bug; the **manual / integration test pass is deferred to the epic boundary** (DD-30).

**Relationship to `/story-flywheel`:** the autonomous, epic-scoped layer above it — same three subagents and model routing (story-flywheel → **Subagent Delegation & Model Routing**; not duplicated here). Adds:
1. commit-per-step so a bad story can be unraveled;
2. within-epic auto-advance on clean stories;
3. an **Epic Boundary Gate** (build+test+evals+invariants across the whole epic, **HALTs for help** on any failure);
4. continuous deferred-item re-homing;
5. a deduplicated **rolled-up test plan** that subtracts what automation already proves, then splits the rest into simulator-runnable vs physical-device-required.

**Phase files** — read each only when its phase is reached, and re-read it then rather than relying on memory (a long epic compacts this context):
- Epic boundary, gates 1–4c and the step 6 report → [boundary-gate.md](boundary-gate.md)
- Epic boundary, step 5 test plan → [test-plan-rollup.md](test-plan-rollup.md)
- Epic boundary, step 5b, only when its condition holds → [squash-merge.md](squash-merge.md)

---

## Iron rules

1. **HALT, don't push forward.** A red Build & Test Gate, a failing eval, an unverifiable invariant, or a dev-story HALT stops the loop and asks the user for help. Never carry a broken story into the next one.
2. **Commit every step.** create → commit → dev → commit → review+patch → commit. The granular trail is what lets you `git bisect`/revert to the precise step that went wrong.
3. **Don't accumulate context.** The orchestrating thread holds only short structured reports from subagents — never full story files or source. The only LLM-heavy work this thread does itself is the one-time test-plan dedup at the epic boundary, over collected plan text only.
4. **Deferred means re-homed, not forgotten.** Every `[Defer]` finding gets a home (slotted as an AC or a remediation story) via the `deferred` skill, and the Epic Boundary Gate sweeps for any orphan.

---

## Activation

1. **Pick the epic.** Same discovery as story-flywheel (sort by epic number embedded in milestone *title*, not GitHub milestone ID; fall back to `docs/epics.md`). Accept `/epic-flywheel {N}` to force one. Announce: "Epic-flywheel for Epic {N}: {title}. {X} stories. I'll run them with per-story gates, commit each step, then do one verification + test-planning pass at the end."

2. **Delegation mode + model routing.** Identical to story-flywheel (→ **Subagent Delegation & Model Routing**):
   - detect `swift_project`;
   - prefer subagent-delegation mode (`lw-story-creator` / `lw-story-developer` / `lw-story-reviewer`);
   - `model: opus` override only for Phase 2 on Swift (never `fable` — the flywheel's cost ceiling is Opus);
   - inline on the session model only when subagents are unavailable.

3. **Detect the Apple platform set.** Set `apple_project = true` if `swift_project`. Read `docs/setup/manifest` / `docs/setup/swift/` and `docs/ux/EXPERIENCE.md` only enough to learn which platforms ship (iOS/iPadOS/macOS). This governs the simulator-vs-physical split at the boundary. Non-Apple projects get a generic "automated/local-runnable vs manual" split instead.

4. **Commit authorization (required for autonomy).** Ask once:
   > Epic-flywheel commits after each step (create / dev / review) so the trail is granular and unravel-able. Authorize automatic commits for this run? (yes / no — if no, I'll pause for you to commit at each step.)

   Detect the commit command: prefer `scripts/commit-push.sh "<msg>"` if it exists in the project, else plain `git add -A && git commit`. Push only if the project's script pushes (don't introduce pushing where the project doesn't).

5. **Autonomy level.** Default is **auto-advance within the epic**: any story whose per-story gates are fully green (no `UNRESOLVED`, PASS rubric, green Build & Test, evals pass, invariants verified) advances without a checkpoint. The loop still stops on red/HALT. Offer the stricter alternative:
   > Default: I auto-advance on clean stories and only stop for problems or the epic boundary. Prefer a checkpoint after *every* story instead? (auto / every-story)

---

## The Per-Story Loop

For each story in the epic, in story order. Spawn each phase as its subagent (cold start; it owns the heavy reading). The orchestrator captures only the structured report fields.

**"Spawn" = a literal Agent tool call** (`subagent_type` = `lw-story-creator` / `lw-story-developer` / `lw-story-reviewer` / `lw-docs-sync`), per story-flywheel → **Spawning a phase** — if a step ends with no Agent call in the transcript, the step did not run.

Its **non-return rule** and PID/artifact wait loops apply here unchanged (DD-21): a report missing its required fields means the phase hasn't returned — resume the subagent via SendMessage, don't advance.

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

- Get `{issue#}` from the create-story report or `grep '^github_issue:' {story_file}`.
- If it's `0`/missing the issue was never created — run github-tracking **CREATE-ISSUE** first, don't silently skip.
- If the script is absent, fall back to the github-tracking TRANSITION/CLOSE-ISSUE ops.
- If `gh` is unavailable the script prints `skip: gh unavailable` and exits 0 — note that once in the boundary report rather than claiming issues were updated.

### Step 1 — Create Story → commit
Spawn `lw-story-creator` with `{epic}.{story}`. Capture `STORY FILE`, `EPIC CONTEXT`, `COMPLEXITY`, `CLARIFICATIONS NEEDED`, `PREREQUISITES`, `DESIGN GAP`.
- **Epic context gate (zero-token, orchestrator-owned):** run `[ -f docs/epics/epic-{N}-context.md ]`. The creator must have generated or reused it (report field `EPIC CONTEXT`). If the file is absent, re-spawn `lw-story-creator` with an explicit prompt to run create-story's **Generate Cache** section for Epic {N}, then re-check. Never advance to Step 2 or commit while the file is missing (DD-23).
- **Clarification Gate (the one mandatory human pause inside a story):** if the report lists *material* clarifications, surface them now and wait for answers; record them into the story file. One-default ambiguities are recorded as stated assumptions and do not pause.
- **Cross-story prerequisite check:** if `PREREQUISITES` names a runtime artifact owned by a *later* story in this or another epic, flag a sequencing risk now — the legitimate "not built yet" case belongs at story-design time, not as a fake bug later.
- **Track:** `gh-track.sh transition {issue#} ready-for-dev`.
- **Commit:** `story {epic}.{story}: create` (stages the story file + the epic context cache if generated/updated this step + any tracking/epics edits).

### Step 2 — Dev Story → commit
1. **Probe:** run CLAUDE.md's `## Probe` command if present — non-zero exit pauses the loop as an environment fault, no spawn, no HALT (story-flywheel → Phase 2).
2. **Track:** `gh-track.sh transition {issue#} in-progress` before spawning, so a long dev pass shows the right state.
3. **Spawn** `lw-story-developer` (`model: opus` only if `swift_project`) with the story file path. It runs the full dev-story workflow: implementation, **Build & Test Gate** (verify by running), **evals RUN** (if `docs/evals/`), and invariant + design verification, then stops at `review`.
4. Capture `STATUS`, `BUILD & TEST`, `BUILD/TEST ITERATIONS`, `EVALS`, `INVARIANTS`, `INFRA TOUCHED`, `UNRESOLVED`, `TESTING PLAN`, `REVIEW HANDOFF`.

Then:
- **On HALT or red gate:** stop the loop. Report which story and why; do **not** commit a red story. Resume with `/epic-flywheel {N}` after the blocker is fixed. A `blocked` environment fault pauses the same way but is not a story failure.
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
Per story-flywheel → Phase 3 (not duplicated here): **always** spawn `lw-story-reviewer` with the developer's `REVIEW HANDOFF` as its prompt, verbatim. It:
- emits the SCORE rubric line;
- auto-patches `patch` findings;
- applies `fix-now` findings within code-review's Triage ceiling (recorded in Review Findings, not logged as deferred);
- logs `defer` via the `deferred` skill (re-homing each — slot as AC or remediation story);
- **re-verifies green**.

`decision-needed` findings surface to the user. `FOLLOW-UP REVIEW: yes` → one follow-up round on `PATCH BASE` (story-flywheel → Phase 3).
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

Read [boundary-gate.md](boundary-gate.md) now for the procedure of gates 1–4c and step 6 — re-read it at the boundary even if it was read earlier. Run in order:

1. **Epic Build & Test Gate (whole project)** — full, unfiltered build + test. Red build / any failing test → **HALT**.
2. **Evals RUN — full cumulative set** — `bash scripts/evals.sh --quiet`. Any regression → **HALT**.
3. **Invariant verification sweep** — any invariant left `[ ] UNVERIFIED` → **HALT** (DD-14).
4. **Deferred sweep** — two-pass; LOG-AND-SCHEDULE any orphan.
   - **4a. CLAUDE.md budget check** (zero-token, non-blocking).
   - **4b. Tracking reconcile** (`gh-track.sh sync`, safety net).
   - **4c. Architecture promotion** — `lw-docs-sync` op `PROMOTE` (DD-58).

### 5. Rolled-up, deduplicated, **subtracted** Test Plan (the manual pass)
Read [test-plan-rollup.md](test-plan-rollup.md) and follow it. It turns the scratch list `docs/epics/.epic-{N}-test-plans.md` into `docs/epics/epic-{N}-test-plan.md` — every section-A flow carries `Automated — do not re-test:` and a full-flag setup command — appends section B to `docs/testing/physical-device-backlog.md`, and deletes the scratch file.

### 5b. Squash-merge to main — Apple / manual-test epics (conditional)
**Only when the manual test pass needs a build the user drives** (`apple_project = true`, or any epic whose test plan must be built/run outside the agent). Skip for web/library epics where the agent runs the tests itself. When it applies, read [squash-merge.md](squash-merge.md) — it merges only if the project's `CLAUDE.md` prescribes merge-at-boundary.

### 6. Boundary report
Print the boundary report and append the epic-level ledger roll-up (both in [boundary-gate.md](boundary-gate.md) → 6). Wait for the user — the boundary is always a human gate.

**Retrospective reminder is mandatory.** The Epic Boundary Gate always surfaces the retrospective prompt — never close an epic silently.

**`/retrospective` is human-in-the-loop even here.**
- It asks the `## Seven Questions` one at a time and waits; generating the retro from git history is forbidden.
- If the user picks `"continue"` (skip retro), confirm once: "Starting Epic {N+1} without a retrospective for Epic {N} — its learnings won't be captured. Proceed?" Honor the choice, but make the skip explicit.
- After `"test"`, re-surface the reminder before advancing.

---

## Exit Conditions

- **All epics complete:** every milestone closed / every story done → final "ALL EPICS COMPLETE" message; suggest `/retrospective` and `/status`.
- **HALT (gate failure or dev-story blocker):** loop stops, reports the exact story/step and the failing output, and asks for help. Resume with `/epic-flywheel {N}` (or `/epic-flywheel {epic}.{story}` to re-enter at a story). The granular commits mean the user can `git reset`/revert to the last good step.
- **User "stop":** graceful exit; report stories remaining and the resume command.

## Resuming

`/epic-flywheel` with no arg detects in-flight state from GitHub labels / `Status:` fields (same rules as story-flywheel):
- `in-progress` → resume at Step 2;
- `review` → resume at Step 3;
- otherwise start at the first incomplete story.
- If all stories are done but no `epic-{N}-test-plan.md` exists, resume directly at the Epic Boundary Gate.

---

## Notes

- **Token posture:** every per-epic gate is zero-token (shell commands and short recorded blocks); the only model-heavy step is the once-per-epic test-plan dedup + subtract.
- **Why subtract before writing the plan:** DD-31. **Why defer manual testing to the boundary:** DD-30. **Why commit-per-step:** a bisectable history, not one giant squash.
