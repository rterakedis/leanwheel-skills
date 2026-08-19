---
name: docs-sync
description: Composable documentation-maintenance operations — keep the human standup/ops/db guides and the canonical architecture doc current as code changes. Called by dev-story and quick-dev (OPERATIONAL), epic-flywheel and retrospective (PROMOTE), and code-review (DRIFT). Directly invocable as /docs-sync to catch the current working tree up.
---

# Docs Sync Skill

Composable doc-maintenance ops. The caller supplies the trigger and context; this skill owns the *how* (DD-24). Every op is gated and idempotent — it does nothing when there's nothing to update.

**Model routing.** OPERATIONAL and PROMOTE are mechanical, diff-grounded prose and run on the cheapest model: callers spawn the `lw-docs-sync` subagent (pinned to Haiku) via a literal Agent tool call — `subagent_type: "lw-docs-sync"`, prompt naming the op (`OPERATIONAL` / `PROMOTE`) and its input (story path / changed-file list / epic number) — rather than running inline:
- The **orchestrator** owns the spawn — `lw-story-developer` does not run doc-sync inline (it can't spawn a child anyway). story-/epic-flywheel spawn after the dev phase returns (OPERATIONAL, story path) and at the epic boundary / retrospective (PROMOTE, epic number).
- Main-session callers (`quick-dev`, standalone `dev-story`, direct `/docs-sync`) spawn likewise.
- **DRIFT is the exception** — a one-line advisory, so it stays inline in the caller.

Fallback when no spawn is possible: run the op inline.

**Three doc audiences, deliberately separated:**
- **Human operational guides** — `docs/setup/` (stand up from scratch), `docs/maintainer/` (operate it / how it works), `docs/sql/` (database). Each area is a hub `index.md` plus focused topical pages. Maintained and grown by **OPERATIONAL**.
- **LLM planning doc** — `docs/architecture.md` (read by `/create-story`, `/epics`, `/check-readiness`). Fed by **PROMOTE**.
- **External-sourced coding guidance** — `docs/setup/swift/` + `docs/setup/web/`. Owned solely by `/refresh-swift` / `/refresh-web`; **DRIFT** only flags it.

> Hard rule across every op: this skill **never** edits `docs/setup/swift|web/`, and **never** creates the top-level `docs/setup` / `docs/maintainer` / `docs/sql` area directories (that's `/setup`'s job — stay silent if an area is absent). Within an existing area it may create new topical files, always linked from that area's `index.md`.

---

## OPERATIONAL — sync the human guides from a changed-file set

Keeps the stand-up / run-it / database guides current as the code grows. This op is where the maintainer runbook that `dev-story`'s Definition of Done requires gets written or updated.

**Input:** the changed-file list for the work just completed (derive with `git diff --name-only` against the last commit or merge-base if the caller didn't supply it).

**Gate (deterministic, zero-token):** match changed paths against the infra-signal set below. If **nothing matches, stop silently**. Also stop silently if the relevant area (`docs/setup/`, `docs/maintainer/`, `docs/sql/`) doesn't exist.

| Changed-file signal | Suggested home |
|---|---|
| Dependency manifest (`package.json`, `requirements.txt`, `pyproject.toml`, `Gemfile`, `go.mod`, `Package.swift`, `Podfile`, `*.gradle`) | `docs/setup/index.md` Prerequisites + install; `docs/setup/resources.md` if a new external service/key is introduced |
| Env / config (`.env*`, config files, new `process.env`/`Environment`/`os.environ` reads) | `docs/setup/resources.md` + the env step in `docs/setup/index.md` |
| DB migration / schema (`migrations/`, `*.sql`, ORM schema files) | `docs/sql/migrations.md` + `docs/sql/schema.md`; db-setup step in `docs/setup/index.md` |
| New runnable script / task (`scripts/`, new `package.json` script, `Makefile` target, `bin/`) | `docs/setup/scripts.md` |
| Deploy / CI / infra (`Dockerfile`, `docker-compose*`, `.github/workflows/`, `fly.toml`, `vercel.json`, `Procfile`, k8s manifests) | `docs/maintainer/runbook.md` (deploy/rollback/ops) + `docs/maintainer/index.md` |
| New long-running service / worker / background-job entrypoint | `docs/maintainer/index.md` Monitoring + a runbook section |

The table is the default home, not a cap. When a signal is a substantial, self-contained topic (a new external integration, a distinct operational procedure, a new subsystem, a sizeable schema area), prefer a new focused page over cramming it into `resources.md`/`runbook.md`/`schema.md`:
- `docs/setup/{service}.md` — e.g. `stripe.md`, `auth0.md` (a new external dependency's keys, config, local-dev setup)
- `docs/maintainer/{procedure}.md` — e.g. `background-jobs.md`, `cache-invalidation.md` (a procedure too big for a runbook section)
- `docs/sql/{area}.md` — e.g. `reporting-schema.md` for a cohesive table cluster

Each new page is short, self-contained, and written to be followed cold. Reuse an existing topical page if one already covers the topic.

**Rules:**
- Stay inside `docs/setup/` (root), `docs/maintainer/`, `docs/sql/` — the hard rule above applies.
- Write idempotently — update in place, never duplicate; link every new page from the area's `index.md` with a link + one-line description.
- **Ground every edit in the actual diff / CI / code.** An operational step that is *inferred* rather than evidenced (e.g. a rollback) is still written but tagged `⚠️ inferred — verify`.

**Return:** `DOCS UPDATED: {comma-list of files written/created, e.g. setup/index.md, setup/stripe.md}` or `none`.

---

## PROMOTE — promote epic learnings into the architecture doc

Story-scoped discoveries accumulate in `docs/epics/epic-{N}-context.md` (written by code-review's epic-context pass); this op carries the durable ones into `docs/architecture.md` so the next epic plans against live docs.

**Input:** the epic number `{N}` (→ `docs/epics/epic-{N}-context.md`).

If the context file is absent or has no `## Story {id} Learnings` blocks, **stop silently**.

Scan the learnings for **project-canonical** facts a future epic must plan against:
- Schema / table / migration realities that differ from what `architecture.md` describes
- New or changed services, modules, integration points, external contracts
- Cross-cutting invariants or constraints established this epic
- Architectural decisions made or reversed during implementation

Append the durable ones to `docs/architecture.md` under a `## Epic {N} — Implementation Learnings` heading (create the heading once, append under it), idempotently — skip anything already reflected there, matching on the *fact* rather than verbatim text. Also note schema-shaped learnings in `docs/sql/` and operational ones in `docs/maintainer/` when those exist.

Promote project reality only — never `docs/setup/*` guidance.

**Verify symbols before writing (mandatory):**

1. List every symbol, type, component, file, or path the drafted text names.
2. `grep` the codebase for each one and confirm it exists at the cited location.
3. Drop or correct any name that doesn't resolve. Only then write or commit the doc.

A name you did not grep is not evidence.

**Return:** count of learnings promoted.

---

## DRIFT — flag stale coding guidance (never auto-write)

Implementation revealed the guidance itself in `docs/setup/swift|web/` is wrong, stale, or contradicted by what the codebase consistently and intentionally does. (A one-off violation is a review finding, not drift.)

**Input:** the observed contradiction.

Do not edit `docs/setup/*` (hard rule above). Emit a single advisory:

```
GUIDANCE DRIFT: docs/setup/{swift|web}/{file}.md — {what the guidance says vs. what the project does}.
Recommend: /refresh-{swift|web} (re-source from upstream) or a deliberate manual setup edit if this is an intended project deviation.
```

Skip silently if the guidance held.

**Return:** the advisory line, or `none`.

---

## Direct invocation (`/docs-sync`)

Derive the changed-file list with `git diff --name-only` against the last commit (or the merge-base of the current branch), then run **OPERATIONAL** over it and report what changed — spawned as `lw-docs-sync` per Model routing above (fallback: inline).
