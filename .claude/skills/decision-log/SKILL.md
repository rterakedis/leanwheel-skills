---
name: decision-log
description: Composable operations on docs/project/decisions.md — the project-wide decision ledger. Called by ideate, spec, correct-course, and retrospective when a direction-setting decision is made, reversed, or parked. Directly invocable as /decision-log to view the current log and open questions.
---

# Decision Log (Composable)

Owns `docs/project/decisions.md` — the single ledger of *why the project is going the way
it's going*. Planning progress is measured in decisions recorded here, not in document
completeness; the spec docs (`docs/prd.md`, `docs/ux/*`, `docs/architecture.md`) are
renderings that cite this log, never a second copy of it.

Directly invocable: `/decision-log` — show the log, grouped as settled / open / out of scope,
with a one-line "what's sharpest to resolve next" suggestion. Read-only in that mode.

## `docs/project/decisions.md` — format

```markdown
# Decision Log

## Destination
<one or two lines: what this planning effort is finding its way to — a spec, a decision, a change>

## Decisions
- {date} — {decision, one line} — why: {reason} — source: {/skill}

## Rejected
- {date} — {what was considered and dropped} — why — source: {/skill}

## Not yet specified
<open questions, one per line — sharp enough to state, not yet answered. The frontier.>

## Out of scope
- {date} — {what was ruled out} — why — source: {/skill}
```

`Decisions` and `Rejected` are append-only one-liners. `Destination`, `Not yet specified`,
and `Out of scope` are living text. Entries carry a `source:` naming the skill that wrote them.

## One home per fact

This log holds *direction* only. Work owed lives in `docs/deferred-items.md` (via `deferred`);
working conventions live in CLAUDE.md; what's being built lives in the spec docs. A fact is
recorded in exactly one of these — when a caller is holding something that's work rather than
a decision, route it to `deferred` LOG-AND-SCHEDULE instead of recording it here.

Writers: `ideate` (primary), `spec` (decisions settled while rendering a section),
`correct-course` (change triggers and their impact decisions), `retrospective` (only learnings
that set or reverse a direction), `discover` (seeding from a brownfield codebase). The dev-loop
skills never write here — a dev session that hits a direction question routes to
`/correct-course`.

## Operations

**LOAD** — read the log (create from the format above if absent, leaving Destination empty for
the caller to fill). Return the open questions and the Destination so the caller can orient.
Never summarize the Decisions section back to the user unprompted — it's an index, not a recap.

**RECORD** — input: `kind` (decision | rejection), `text`, `why`, `source`. Append the
one-liner to the matching section. If the decision answers a line in `Not yet specified`,
remove that line in the same edit. If it contradicts an earlier decision, don't rewrite
history: append the new decision and note "supersedes {date} entry".

**PARK** — input: `question`, `source`. Add to `Not yet specified` — for questions surfaced
mid-work that shouldn't be resolved in the current pass. Don't pre-slice a fuzzy area into
many parked lines; one coarse line is right until the frontier reaches it.

**RULE-OUT** — input: `text`, `why`, `source`. Append to `Out of scope`. Out-of-scope items
never graduate back on their own — they return only if the Destination is redrawn.

**STATUS** — return counts (settled / open / out of scope) and whether `Not yet specified` is
empty. An empty frontier with a filled Destination means the way is clear: the caller should
hand off to `/spec` rather than keep looping.
