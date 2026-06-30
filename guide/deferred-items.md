[← Back to README](../README.md)

## Deferred Items — Lifecycle and Re-Homing

A "deferred" finding is something `/dev-story`, `/code-review`, `/correct-course`, `/investigate`, or `/quick-dev` noticed but decided not to fix in the moment — too big for the current story, out of scope, or a genuine "later" item. Original BMAD let these findings go nowhere once deferred. BMAD-LITE auto-schedules every one as real, trackable work and actively sweeps for items that fall through.

### The model

Every deferred item is a row in `docs/deferred-items.md` — the single source of truth, append-only:

| ID | Title | Detail | Source | Scheduled As | Date |
|----|-------|--------|--------|--------------|------|
| D-1 | {title} | {issue} | `{file}` | Story {epic}.{N} (slotted as AC) | {date} |

`Scheduled As` is the load-bearing column: every deferred item must point at an **open** (not-started or in-progress) story. An item with no schedule, or one pointing at a story that's since been completed or removed, is an **orphan**.

### How an item gets logged and scheduled

The composable [`/deferred`](../.claude/skills/deferred/SKILL.md) skill's `LOG-AND-SCHEDULE` operation runs automatically whenever a calling skill triages a finding as "defer" — the user never manages a queue by hand:

1. **Try to slot it into existing backlog first** (`SLOT-INTO-BACKLOG`). Score every `not-started` story in `docs/epics.md` by domain match (security/UI/perf/auth finding → matching-domain story) and proximity (next unstarted epic). On a match, the item is appended as a new Acceptance Criterion on that story — no new story created.
2. **Fall back to a new remediation story** (`SCHEDULE` Step 2) if nothing scores high enough — placed in the epic whose scope naturally fits, or `Epic R: Remediation` if every epic is already complete.
3. Append the row to `docs/deferred-items.md`, and mark `[x] [Defer]` in the source file (story, review, investigation case) with the D-ID and the story it landed in.

### Why orphans happen anyway

Scheduling at creation time isn't the whole story — the target can go stale *after* the item is logged:
- The story it was slotted into reaches `Status: done` and locks, but the AC inside it never got addressed.
- An epic gets restructured and the story is renamed or removed from `docs/epics.md`.
- A finding gets hand-written as `[Defer]` directly in a story file (e.g. during manual editing) without ever calling `LOG-AND-SCHEDULE`, so it never made it into `docs/deferred-items.md` at all.

### The two safety nets

Two independent passes catch orphans — one manual, one automatic:

**`/retrospective`** (run once per completed epic) — a two-pass audit:
- **Pass 1 — catch unlogged items:** scans every story file in the epic for `[Defer]` checkboxes with no matching D-ID in `docs/deferred-items.md`, and logs any found via `LOG-AND-SCHEDULE`.
- **Pass 2 — verify schedules are still valid:** for every row in `docs/deferred-items.md`, checks whether `Scheduled As` still points at open work. A `done`-story or a removed/renamed story triggers reassignment (re-run `SLOT-INTO-BACKLOG`, or `SCHEDULE` Step 2 if no slot exists) and an update to the row.
- Hard rule enforced by the skill: every unresolved deferred item must point to an open, not-started story when the retro ends — narrating the problem without editing the log file is a failed retro.

**`/epic-flywheel`**'s Epic Boundary Gate — the same two-pass sweep, but it runs **automatically at the end of every epic**, not just when you remember to invoke `/retrospective`. It's one of the gate's iron rules ("deferred means re-homed, not forgotten") and any orphan found is reported in the boundary summary (`Deferred re-homed this epic: {n} (0 orphans)`). Because `/epic-flywheel` can drive several epics with minimal steering, this is what actually prevents items from silently rotting in an unattended run.

### Checking on the log yourself

`/deferred` with no arguments shows the full log plus each scheduled story's current status (not started / in progress / done) — replaces grepping the project for `[Defer]` by hand.

### If you're on an older project

The two-pass re-homing audit landed in `/retrospective` in June 2026 and the automatic Epic Boundary Gate sweep shortly after in `/epic-flywheel`. A project scaffolded before then only has `LOG-AND-SCHEDULE`'s point-in-time scheduling, with no mechanism to catch items that go stale later. Run `/upgrade-project` to pull current skill versions, then run `/retrospective` once to sweep any existing orphans before relying on the automatic gate going forward.
