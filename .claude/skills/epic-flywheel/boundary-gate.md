# Epic Flywheel — Epic Boundary Gate: gates 1–4c and the boundary report

Read at the epic boundary, when the last story in the epic has finished its per-story loop. Re-read it then even if read earlier — the epic's run may have compacted context. All stories are implemented, reviewed, and individually green; these gates verify the epic *as a whole*.

**Outcome rule: any failure here HALTs and asks for help — do not start the next epic.**

Order: gates 1 → 4c below, then SKILL.md step 5 (test plan, `test-plan-rollup.md`) and step 5b (conditional squash-merge), then section 6 here.

## Contents
- 1. Epic Build & Test Gate (whole project)
- 2. Evals RUN — full cumulative set
- 3. Invariant verification sweep
- 4. Deferred sweep · 4a CLAUDE.md budget · 4b Tracking reconcile · 4c Architecture promotion
- 6. Boundary report

## 1. Epic Build & Test Gate (whole project)
Run a full, unfiltered build + test — not story-scoped:
- Apple: `xcodebuild -quiet … build test` (and `swift build -q && swift test -q` for SPM targets).
- Web: the project's quiet build + test scripts.
- Else: the documented project command.

Use the project CLAUDE.md `## Quiet commands` invocations when present; always `tee` the full log to `.leanwheel/logs/` and keep only the tail in context (dev-story → Build & Test Gate).

**Apple projects — also, always, whatever each story ran (DD-84):**
- the **whole** device / layout matrix — every cell. Stories that did not touch layout ran one cell per width class in their final cycle; this is where the rest is run.
- the **release guard** (or a plain Release-configuration build when the project has none).
- Score the full-plan log with the project's scorer when it has one. Run on a tree that contains main.

These run once here, not once per story, because they are the slow part of the cycle. Pinned counts changed by the epic are reset by the project's script, never by hand (`skills/story-flywheel/final-cycle.md` → *Pinned counts*).

Red build / any failing test / red matrix cell / red release guard → **HALT**: report the failing target/test output and ask the user how to proceed.

## 2. Evals RUN — full cumulative set
Run `bash scripts/evals.sh --quiet` — every epic, not just this one (per evals → RUN). Any regression → **HALT**, listing the failing cases.

## 3. Invariant verification sweep
Collect the `### Invariant Verification` blocks recorded by dev-story across this epic's stories (read the short blocks, not full files). Any invariant left `[ ] UNVERIFIED` (no test, no cited enforcing `file:line`) → **HALT** and surface it for the user (DD-14).

## 4. Deferred sweep
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
Call the Agent tool with `subagent_type: "lw-docs-sync"` (Haiku) and a prompt naming op `PROMOTE` and Epic {N} (fallback: execute the docs-sync **PROMOTE** op inline if subagents are unavailable).
- It harvests project-canonical learnings from `docs/epics/epic-{N}-context.md` and appends the durable ones to `docs/architecture.md` (idempotent; also `docs/sql/` / `docs/maintainer/` when present) — see DD-58.
- Zero-token when the context file has nothing canonical; never touches `docs/setup/*` guidance.
- Report the count promoted in the boundary report.

## 6. Boundary report
Run after step 5 (and 5b when it applies). `{a}`, `{b}`, `{s}`, `{g}` come from the step 5 test plan.

```
─────────────────────────────────────────────
EPIC {N} COMPLETE & VERIFIED — {X} stories
─────────────────────────────────────────────
Build & Test (whole project): {green | HALTED}{ · matrix {n}/{n} cells · release guard green — Apple}
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

Append the epic-level roll-up via `scripts/ledger.sh epic-flywheel --story epic-{N} --models … --build-test … --evals …`. Wait for the user — the boundary is always a human gate. The retrospective reminder and its skip-confirmation rules are in SKILL.md → Epic Boundary Gate → 6.

**Last epic of the phase.** If no later epic remains in `docs/epics.md`, add one more line to the recommended flow after step 3: `4. → Optionally /epic-archive cut-release {version} to archive this phase's epics.md and seed a fresh one for the next phase.` An offer only — never cut a release automatically.
