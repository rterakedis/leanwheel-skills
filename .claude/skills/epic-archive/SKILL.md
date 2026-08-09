---
name: epic-archive
description: Composable operations that keep docs/epics.md from growing without bound — collapse a closed epic's story detail to a summary row, and cut a shipped release into an archive file. Called by /retrospective. Directly invocable as /epic-archive.
---

# Epic Archive (Composable)

`docs/epics.md` is read in full by `check-readiness`, the first `create-story` of each epic, every `retrospective`, `correct-course`, `doc-review`, and `epics` update runs — 15–25 full reads over a project's life. Left alone it grows monotonically: every shipped story's user-story statement and Given/When/Then ACs sit there forever, **duplicating** the story file in `docs/epics/{N}-{M}-{slug}.md`, which holds the same ACs *plus* the implementation record, File List, and review results. The duplicate is the dead weight; the story file is the record.

This skill removes that duplication in two layers:

- **CONDENSE** — at epic close, collapse the epic's per-story bodies to one summary row each (~120 lines → ~10). Bounds growth *within* a release. This is the load-bearing op.
- **CUT-RELEASE** — at a phase/release boundary, move the whole active `docs/epics.md` into `docs/epics/releases/` and seed a fresh one for the next phase.

**Iron rule — condensing is not deleting.** Every collapsed story keeps its id, title, status, and a link to its story file. Nothing is removed that isn't recoverable in one hop. A story with no file, or a file that is not `status: done`, is **never** collapsed.

**Token posture (Pro plan):** both ops are cheap structured edits over one file — no doc synthesis, no subagent, no model-heavy reasoning. Both are idempotent: re-running finds the work already done and no-ops.

Directly invocable: `/epic-archive` — report which epics are collapsible and whether a release cut is available, then offer to run them. Also called as a composable step by `/retrospective`.

**Compose, don't reimplement.** This skill orchestrates existing artifacts:
- `docs/epics/{N}-{M}-{slug}.md` — the story files that *become* the source of truth for collapsed detail.
- `skills/deferred/SKILL.md` — re-homing any deferred item whose `Scheduled As` story lands in a cut release.
- `skills/github-tracking/SKILL.md` — milestones/issues are untouched by both ops (numbering stays continuous; see below).

---

## Activation

1. Require `docs/epics.md`. If absent, report `No docs/epics.md — nothing to archive` and stop.
2. Read the stamps below the H1 — they are the deterministic state signal:
   ```bash
   grep -o 'retro: epic [0-9]*' docs/epics.md 2>/dev/null || echo "no retro stamps"
   grep -m1 'readiness-check' docs/epics.md 2>/dev/null || echo "no readiness stamp"
   ls docs/epics/releases/*.md 2>/dev/null || echo "no releases archived"
   ```
3. Direct invocation with no op → report state (collapsible epics, release-cut availability) and ask which to run. A caller naming an op runs it directly.

---

## CONDENSE

Input: `epic_num`.
Called by: `retrospective` (after the deferred sweep, before the retro stamp). Also runnable directly.

**No new marker.** `retrospective` already writes `<!-- retro: epic {N} — {date} -->` below the H1, which *is* "epic N is closed" — do not introduce a second stamp.

Note the ordering: `retrospective` calls CONDENSE **before** it writes that stamp. So the stamp is **not** an input to CONDENSE — eligibility is decided per-story in Step 1 (file on disk + `status: done`), and a caller passing `epic_num` is asserting the epic is closing. The stamp is a *discovery* signal for other readers (`/next`, and this skill's own Activation when invoked directly with no epic given). Never refuse to condense because the stamp isn't written yet.

### Step 1 — Eligibility (deterministic, per story)

For each `### Story {N}.{M}` under `## Epic {N}` in `docs/epics.md`, resolve its story file `docs/epics/{N}-{M}-*.md` and read the **frontmatter** `status:`:

| Story state | Action |
|---|---|
| File exists, frontmatter `status: done` | **collapse** → summary row |
| File exists, any other status (`in-progress`, `review`, `ready-for-dev`) | **keep full entry** |
| No file | **keep full entry** (unbuilt backlog — `create-story` still needs to find it) |
| Deferred / descoped / superseded | **keep the row, marked** — never silently drop |

If **no** story in the epic is collapsible, report `Epic {N}: nothing to condense` and stop. If *some* are, collapse those and leave the rest full — a half-finished epic condenses partially and correctly.

Read `status:` from frontmatter only. Tolerate the legacy `**Status:** ✅ Done` body line on read (same normalization `gh-track.sh` does) — but treat an *ambiguous* or unparseable status as **not** collapsible.

### Step 2 — Rewrite the epic section

Replace the epic's collapsible `### Story` blocks with a single table, preserving the epic header, goal, and FR coverage line verbatim:

```markdown
## Epic 3: Payments & Billing

**Goal:** Users can subscribe, change plan, and see invoices.
**FRs covered:** FR-9, FR-10, FR-11, FR-12, FR-13, FR-14

| Story | Title | Status | Spec |
|-------|-------|--------|------|
| 3.1 | Stripe customer sync | done | [3-1-stripe-customer-sync.md](epics/3-1-stripe-customer-sync.md) |
| 3.2 | Checkout flow | done | [3-2-checkout-flow.md](epics/3-2-checkout-flow.md) |
| 3.3 | Invoice history | done | [3-3-invoice-history.md](epics/3-3-invoice-history.md) |
| 3.4 | Plan downgrade guard | deferred → 5.2 | — |
```

What must survive the collapse — these are load-bearing for other skills, not decoration:

- **Epic number, title, goal, FR-covered line** — `check-readiness` FR traceability and `correct-course` scope reads.
- **Every story id and title** — `retrospective`'s `Scheduled As` lookup against `docs/deferred-items.md`, and `/next`'s numbering skim.
- **A link to each story file** — the one hop to full detail.
- **Non-done rows in their real state** — a deferred story shows where it went (`deferred → 5.2`), so a reader never concludes it shipped.

Do **not** touch the `## FR Coverage Map` or the `## Epic List` table at the top of the file. They are small, they are the navigational spine, and they must stay complete.

### Step 3 — Fold in resolved post-test findings

`harvest-findings` appends `### Epic {N} — Post-Test Findings (harvested {date})` blocks to `docs/epics.md`. For each such block belonging to this epic:

- **Every** finding resolved (corrective ones landed in a remediation story that is now `status: done`; enhancements/deferrals logged in `docs/deferred-items.md`; no `needs decision` rows left) → replace the block with one line appended under the epic's table:
  `_{K} post-test findings harvested {date} → resolved in Story {N}.{last} · deferred items D-{a}, D-{b}._`
- **Any** finding still open, or any `needs decision` row → **leave the whole block intact**. An unresolved finding is live work.

### Step 4 — Report

```
CONDENSED Epic {N}: {C} stories collapsed, {K} kept full ({reasons}), {F} finding blocks folded
Saved: ~{lines_before − lines_after} lines in docs/epics.md
```

Idempotent: an already-collapsed epic reports `already condensed` and changes nothing.

---

## CUT-RELEASE

Input: `version` (e.g. `v1.0`, `phase-1`). Ask for it if not supplied — this is the human's name for what shipped.
Called by: `retrospective`'s closing report when every epic in the active file is closed. Also runnable directly.

**Precondition (deterministic).** Every epic in `docs/epics.md` must be closed: each has a `retro:` stamp, and no story row is `ready-for-dev` / `in-progress` / `review`, and no story lacks a file. If anything is open, report what is still open and stop — **never** cut a release over live work.

### Step 1 — Archive

```bash
mkdir -p docs/epics/releases
git mv docs/epics.md docs/epics/releases/{version}-epics.md 2>/dev/null || mv docs/epics.md docs/epics/releases/{version}-epics.md
```

Insert a provenance line below the archive's H1, preserving the existing `retro:` stamps in place:
`<!-- released: {version} — {date} · archived from docs/epics.md -->`

The `readiness-check` stamp stays with the archive and is **not** carried forward — see Step 3.

### Step 2 — Seed the new `docs/epics.md`

```markdown
# {Project Name} — Epics & Stories

## Shipped Releases

| Release | Epics | Stories | Date | Archive |
|---------|-------|---------|------|---------|
| v1.0 | 1–7 | 31 | 2026-07-26 | [v1.0-epics.md](epics/releases/v1.0-epics.md) |

## FR Coverage Map

| FR | Title | Covered By |
|----|-------|-----------|
| FR-31 | {short title} | Story {N.M} |

## Epic List

| # | Title | Goal | Stories |
|---|-------|------|---------|
```

Carry forward:
- The `## Shipped Releases` table (append a row per cut; the previous table comes with the carried header).
- **Any epic that was not closed** — carried whole, full story bodies intact. (In practice the precondition means there are none, but a forced cut must not lose work.)
- Nothing else. The new file starts empty of story detail; `/epics` fills it for the new phase.

### Step 3 — Numbering, stamps, and re-homing

**Numbering stays continuous across releases — deliberately.** If v1.0 ended at Epic 7 and FR-30, the new phase starts at **Epic 8** and **FR-31**. Renumbering would break GitHub milestone titles (`story-flywheel` sorts on the epic number embedded there), story filenames `{N}-{M}-{slug}.md`, `docs/deferred-items.md` `Scheduled As` references, and every `retro:` stamp. Say this back to the user when cutting, so a "fresh start at Epic 1" expectation is corrected before it's acted on.

**Stamps:**
- `retro:` stamps travel with the archive.
- The `readiness-check` stamp does **not** carry over. The new phase has new scope and must be gated on its own. `/next` will see no readiness stamp on the fresh `docs/epics.md` and route to `/check-readiness` — this is intended, not a gap.

**Re-home orphaned deferred items.** Scan `docs/deferred-items.md`: any unresolved row whose `Scheduled As` story now lives only in the archive is orphaned. Call **LOG-AND-SCHEDULE** / **SCHEDULE** from `skills/deferred/SKILL.md` to re-home it into the new phase's backlog. (`retrospective`'s Pass 2 sweep does the same check; running both is safe.)

**GitHub is untouched.** Milestones and issues for archived epics stay as they are — closed and continuous. No relabeling, no migration.

### Step 4 — Report

```
RELEASE CUT: {version} — {E} epics, {S} stories archived → docs/epics/releases/{version}-epics.md
New docs/epics.md seeded. Next epic: {last+1}. Next FR: FR-{last+1}.
Readiness stamp reset — the new phase must pass /check-readiness.
{R} deferred items re-homed.
Next: `/spec` prd update for the new phase scope, then `/epics`, then `/check-readiness`.
```

---

## Rules

- **Never collapse a story that isn't `status: done` with a file on disk.** Unbuilt backlog entries must stay full — `create-story` finds the next story by looking for an epics.md entry with no story file, and `check-readiness` validates upcoming work from these bodies.
- **Never move story files.** Done stories stay in `docs/epics/` alongside active ones. Moving them saves zero tokens (story files are read by explicit path, never bulk-read) and would make `create-story`'s "no file" glob read them as missing and recreate them. `status: done` in the frontmatter is already the machine-readable signal.
- **Never touch `docs/epics/epic-{N}-context.md`, retros, test plans, or story files.** This skill edits `docs/epics.md` only (plus the release archive it creates).
- **Never renumber** epics, stories, or FRs.
- Both ops are idempotent and safe to re-run.
- CONDENSE is per-epic and local; CUT-RELEASE is whole-file and gated. Never run CUT-RELEASE implicitly — it always takes an explicit user go-ahead.
