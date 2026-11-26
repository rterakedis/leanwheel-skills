# Flywheel — the Final Cycle (Swift / Apple projects)

Read when a story's review has come back green and `swift_project = true` (story-flywheel Phase 3b, epic-flywheel Step 3b). Re-read it at that point rather than relying on memory. Other stacks skip this file: their phases still run the whole suite each time, because it costs seconds.

## Contents
- Why there is exactly one
- Who runs it
- Procedure (steps 1–7)
- On red
- Report (`FINAL CYCLE`)
- Pinned counts

## Why there is exactly one

On an app with an XCUITest plan, one whole verification cycle — clean full plan, device matrix, the epic's evals, Release build — costs about an hour. When the developer, the reviewer, the follow-up reviewer, and the merge each ran all of it, a story took three to four hours, most of it re-proving code that had not changed since the last green run (DD-84).

So the phases before this one run **in proportion to what they changed**, and this cycle is the one place everything runs together:

- It runs **once per story**, on the story's tree **merged with the main branch**, immediately before the PR / merge / close. Nothing merges without it.
- It is the **safety net**. A width, suite, or configuration no earlier phase ran is caught here or not at all — a layout flaw once reached main because one width was never run by any scored gate. The goal is one full cycle, never zero.
- **Cost accepted, on purpose:** a bug surfaces later (here, not mid-review), and a red final cycle takes longer to trace because several phases' changes are in the tree. That is cheaper than four to six full cycles per story. Do not restore "run everything in every phase" to get the earlier signal back — if a class of bug keeps arriving here, widen what the *developer's* targeted run covers for that kind of story.

When a case is not covered below, decide it from those three facts.

## Who runs it

The orchestrator owns it: every step is a shell command whose log is `tee`'d to `.leanwheel/logs/` and whose tail is read — zero model tokens while it runs. Wait on the PID or the log artifact (story-flywheel → wait loops). If the orchestrator's context is tight, delegate it as **its own step** — one Agent call whose prompt is this file's path, the story path, and the `FINAL CYCLE NEEDS` value — never folded into the developer's or the reviewer's spawn, whose reports would then mix "proven on the merged tree" with "proven before the merge".

## Procedure

Commands come from the project CLAUDE.md `## Quiet commands` (named entries: full plan, log scorer, matrix, release guard, pin reset). A missing entry means that step falls back as noted, never that it is silently skipped.

1. **Get onto the merged tree.** `git fetch`, then merge the main branch into the story's branch (in the story's worktree if it has one).
   - Already contains main (`git rev-list --count HEAD..origin/{main}` is 0) → nothing to merge.
   - Uncommitted work and commits are not authorized for this run → pause and ask the user to commit; the cycle cannot prove a tree that does not exist yet.
   - Conflict in a **pinned count** or generated file → never resolve it by hand; take either side and regenerate (see *Pinned counts*). Conflict in a String Catalog → take either side; step 6 regenerates it. Any other conflict is real work: spawn `lw-story-developer` with the conflict list.
2. **Full plan, clean, unfiltered.** The project's full-plan command from a clean build. Score the log with the project's log scorer if it has one (`docs/setup/swift/simulator.md` → *A green-looking log is not a green run*): only its green token counts. No scorer → every expected test target reported an executed count, and no failure line.
3. **Device / layout matrix, sized by need.** Read `FINAL CYCLE NEEDS: matrix=` (the higher of the developer's and reviewer's values):
   - `full` — the story touches layout, navigation, or the root view → every cell.
   - `width-class` — any other story → one cell per width class (one compact, one regular; each further class the project defines).
   - The whole matrix always runs at the epic boundary (epic-flywheel → boundary-gate.md), so a `width-class` story is never the last word.
   - No matrix command in the project → `n/a`, stated.
4. **Evals RUN for the epic** — `bash scripts/evals.sh --epic {n} --quiet`, if `docs/evals/` exists. This is the story's one epic RUN. The full cumulative set runs at the epic boundary.
5. **Release guard** when `FINAL CYCLE NEEDS: release-guard=yes` — the story touches a launch argument or DEBUG-only code. Run the project's release-guard command; none → a plain Release-configuration build. Skipped otherwise, and always run at the epic boundary.
6. **String Catalog** — **CHECK** from `skills/sync-string-catalog/SKILL.md`, always (the catalog is an expected merge casualty). `drift` → SYNC and re-check. `unavailable` → blocked.
7. **Record** the merged tree (`git rev-parse HEAD`) and each log path in the `FINAL CYCLE` report below.

A step that cannot run (device, toolchain, Xcode unavailable) is `blocked` — an environment fault that pauses the flywheel (DD-80), never a pass and never a story failure.

## On red

The story is not done and is not merged, closed, or PR'd.

1. Spawn `lw-story-developer` with the story path and the failing log's path and failing line — the fix is development work, not orchestrator work.
2. A fix of more than a few lines is new, unreviewed code: send its diff through `lw-story-reviewer` (base = the tree before the fix).
3. **Re-run this whole cycle** — the tree changed, so the previous logs prove nothing about it. A second red on the same failure → HALT and ask the user.

## Report (`FINAL CYCLE`)

Goes in the story checkpoint and gates the commit / PR / close:

```
FINAL CYCLE: green | red(<step>: <one line>) | blocked(<why>) | n/a (not a Swift project)
  tree: {merged HEAD sha} (main at {sha})
  full plan: {log path} — {scorer token or counts}
  matrix: full {n} cells | width-class {n} cells | n/a — {log path}
  evals: {p}/{t} (epic {n})
  release guard: green | not required | n/a
  catalog: {CATALOG value}
```

Anything other than `green` (or `n/a` off Swift) stops the story from advancing.

## Pinned counts

Applies to every phase and every stack. A project that pins counts — test totals, suite lists, matrix cells, file counts a scorer or guard compares against — changes them **only by running its reset script** on a fresh log, never by hand. Hand-edited pins cause most merge conflicts between stories and most of the rework after them: two branches each bump the same number, and a hand merge of two numbers is a guess.

- Reset script exists (`## Quiet commands` → pin reset) → run it after the run that legitimately changes the counts, and commit its output.
- Pins exist and no script does → do not hand-edit to get past the gate. Report it as a finding (`pins without a reset script: {where}`) proposing a one-command reset as its own small change, and ask the user how to proceed for this story.
