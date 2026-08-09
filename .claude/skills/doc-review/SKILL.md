---
name: doc-review
description: Editorial review of a doc as writing — structure (cuts, reorganization), prose (clarity fixes), and an adversarial pass (gaps, ambiguities, contradictions). Use when the user says "doc review", "tighten this doc", "review the PRD as writing", or "editorial review".
---

# Doc Review Skill

**Goal:** Review a document as *writing*, not as a plan. `/check-readiness`
checks whether the planning docs are aligned and complete; this skill checks
whether they are clear, dense, and unambiguous. Planning docs are re-read by
the model in every downstream session — cutting a bloated PRD by 30% is a
token saving that recurs on every `/create-story`, `/dev-story`, and flywheel
run for the life of the project. Three passes, one skill.

**CONTENT IS SACROSANCT (Passes A + B):** never change what ideas say — only
how they're organized and expressed. Pass C may *question* substance, but it
only reports; it never edits meaning.

## Inputs

- **target** — file path. If none given, offer: `docs/prd.md`,
  `docs/architecture.md`, `docs/epics.md`, `docs/project/brief.md`, or
  "other".
- **reader type** — auto-detected, confirm with user:
  - `llm` for docs consumed by AI sessions (`prd.md`, `architecture.md`,
    `epics.md`, epic-context files, `CLAUDE.md`): consistent terminology, no
    hedging, unambiguous antecedents, dependency-first ordering, structured
    formats over prose. LLM docs may get *longer* where explicitness beats
    brevity.
  - `humans` for guides (`docs/setup/`, `docs/maintainer/`, README, guide
    files): preserve comprehension aids — examples, summaries, expectation-
    setting, visual breathing room. Don't cut warmth as "fluff".

## Pass A — Structure (always first)

1. State the doc's purpose in one sentence: "This document exists to help
   {audience} accomplish {goal}." Confirm if uncertain.
2. Pick the structure model it should follow: **pyramid** (PRDs, proposals —
   conclusion first, MECE groupings), **reference** (consistent per-item
   schema, random access), **linear** (tutorials — prerequisites before
   steps), or **explanation** (abstract → concrete).
3. Map sections with rough word counts. For each: does it serve the purpose?
   Is critical information buried? Is anything truly redundant (identical
   information twice — summaries and reinforcement don't count for `humans`)?
   Out of scope for this doc (cut or link)?
4. Emit recommendations, each tagged **CUT / MERGE / MOVE / CONDENSE /
   QUESTION / PRESERVE** with a one-sentence rationale and estimated words
   saved.

## Pass B — Prose

On the (proposed) surviving text: minimal-intervention fixes for issues that
impede comprehension — not style preferences. Skip code blocks, frontmatter,
tables of data. Deduplicate (same issue in N places = one entry listing
locations); phrase uncertain fixes as "Consider: …?". Output a three-column
table: Original | Revised | Why.

## Pass C — Adversarial

Skeptical re-read, looking for what's *missing or wrong*, not how it's
worded: sections the doc type demands but lacks; claims with no support;
statements an implementing session would misread ("fast", "simple", "handle
errors gracefully" with no criteria); internal contradictions; and — when the
target is a planning doc — contradictions with its siblings (`prd.md` vs
`architecture.md` vs `epics.md`, read only the relevant sections). Output a
flat findings list. Zero findings is suspicious — re-read once before
accepting it.

## Apply

Present the combined report (A recommendations, B table, C findings) with a
before/after word estimate, then ask what to apply: **all / structure only /
prose only / by number / none**. Apply accepted A+B edits directly.

Pass C findings are **not** edits — a material content gap in a planning doc
routes to `/spec` (prd or architecture update) or `/correct-course`; never silently
rewrite what the doc *means* under the banner of editing.

Close with: `DOC REVIEW: {file} — {before} → {after} words ({pct}%), {n}
prose fixes, {m} adversarial findings ({routed where})`.

## When to run

After a `/spec` render and before `/check-readiness`; any time
a doc feels bloated; after several `/spec` prd-update cycles have accreted
sediment. Works on any markdown doc, including this repo's own skill files.
