---
name: docs-sync
description: Composable documentation-maintenance operations — keep the human standup/ops/db guides and the canonical architecture doc current as code changes. Called by dev-story and quick-dev (OPERATIONAL), epic-flywheel and retrospective (PROMOTE), and code-review (DRIFT). Directly invocable as /docs-sync to catch the current working tree up.
---

# Docs Sync Skill

Composable doc-maintenance ops. Other skills call these instead of duplicating the logic — the caller supplies the trigger and context; this skill owns the *how*. Single source of truth, so the mechanics never drift between callers.

**Token posture (Pro plan):** every op is gated and idempotent — it does nothing (zero model cost) when there's nothing to update, and never reads source it doesn't need. The OPERATIONAL gate is a deterministic match on a changed-file list the caller already holds.

**Model routing — this work belongs on the cheapest model.** OPERATIONAL and PROMOTE are mechanical, low-reasoning prose grounded in a diff; they must **never** run on Opus and should run below Sonnet where possible. Because a skill can't pick its own model (it inherits the caller's), the flywheels and main-session callers run these ops by **spawning the `lw-docs-sync` subagent (pinned to Haiku)** rather than inline:
- The **orchestrator** owns the spawn — the `lw-story-developer` subagent (which on Swift is **Opus**) must **not** do doc-sync inline, and can't spawn a child anyway (no nesting). story-/epic-flywheel spawn `lw-docs-sync` after the dev phase returns (OPERATIONAL, passing the story path) and at the epic boundary / retrospective (PROMOTE, passing the epic number).
- **Main-session callers** (`quick-dev`, standalone `dev-story`, direct `/docs-sync`) likewise spawn `lw-docs-sync` so the work lands on Haiku regardless of the session model.
- **DRIFT is the exception** — it only emits a one-line advisory, so it stays inline in whatever called it (already Sonnet in code-review); spawning a subagent to print a string would cost more than it saves.

The fallback when no spawn is possible (e.g. already inside a non-orchestrated subagent) is to run the op inline — correct, just not as cheap.

**Three doc audiences, deliberately separated:**
- **Human operational guides** — the `docs/setup/` (stand up from scratch), `docs/maintainer/` (operate it / how it works), and `docs/sql/` (database) areas. Each area is a hub `index.md` plus as many focused topical pages as the project needs. Maintained — and **grown** (new pages added and linked from `index.md`) — by **OPERATIONAL**.
- **LLM planning doc** — `docs/architecture.md` (read by `/create-story`, `/epics`, `/check-readiness` to plan the next epic). Fed by **PROMOTE**.
- **External-sourced coding guidance** — `docs/setup/swift/` + `docs/setup/web/`. **Never written by this skill** — owned solely by `/refresh-swift` / `/refresh-web`. **DRIFT** only *flags* it.

> The hard rule across every op: this skill **never** edits `docs/setup/swift|web/`, and **never** creates the top-level `docs/setup` / `docs/maintainer` / `docs/sql` area directories themselves (that's `/setup`'s job — stay silent if an area is absent). Within an existing area it *may* create new topical files freely, always wiring them into that area's `index.md`.

---

## OPERATIONAL — sync the human guides from a changed-file set

Keeps the stand-up / run-it / database guides from rotting into stale `{placeholder}` text as the code grows.

**Input:** the changed-file list for the work just completed. The caller usually has it; if not, derive it (`git diff --name-only` against the last commit or merge-base).

**Gate (deterministic, zero-token):** match changed paths against the infra-signal set below. If **nothing matches, stop silently** — most changes touch none of this. Also stop silently if the relevant area (`docs/setup/`, `docs/maintainer/`, `docs/sql/`) doesn't exist at all — creating the *directory structure* is `/setup`'s job, not this op's.

| Changed-file signal | Suggested home |
|---|---|
| Dependency manifest (`package.json`, `requirements.txt`, `pyproject.toml`, `Gemfile`, `go.mod`, `Package.swift`, `Podfile`, `*.gradle`) | `docs/setup/index.md` Prerequisites + install; `docs/setup/resources.md` if a new external service/key is introduced |
| Env / config (`.env*`, config files, new `process.env`/`Environment`/`os.environ` reads) | `docs/setup/resources.md` + the env step in `docs/setup/index.md` |
| DB migration / schema (`migrations/`, `*.sql`, ORM schema files) | `docs/sql/migrations.md` + `docs/sql/schema.md`; db-setup step in `docs/setup/index.md` |
| New runnable script / task (`scripts/`, new `package.json` script, `Makefile` target, `bin/`) | `docs/setup/scripts.md` |
| Deploy / CI / infra (`Dockerfile`, `docker-compose*`, `.github/workflows/`, `fly.toml`, `vercel.json`, `Procfile`, k8s manifests) | `docs/maintainer/runbook.md` (deploy/rollback/ops) + `docs/maintainer/index.md` |
| New long-running service / worker / background-job entrypoint | `docs/maintainer/index.md` Monitoring + a runbook section |

**Create new topical files freely — the goal is human-consumable docs, not one fat file.** The table is the *default* home, not a hard cap. When a signal represents a substantial, self-contained topic (a new external integration, a distinct operational procedure, a new subsystem, a sizeable schema area), prefer a **new focused page** over cramming it into `resources.md`/`runbook.md`/`schema.md`:
- `docs/setup/{service}.md` — e.g. `stripe.md`, `auth0.md` (a new external dependency's keys, config, local-dev setup)
- `docs/maintainer/{procedure}.md` — e.g. `background-jobs.md`, `cache-invalidation.md` (a procedure too big for a runbook section)
- `docs/sql/{area}.md` — e.g. `reporting-schema.md` for a cohesive table cluster

Each new page is short, self-contained, and written to be followed cold. **Always wire a new page into the area's `index.md`** with a link + one-line description so `index.md` stays the hub that ties the pieces into a coherent process — a reader starts at `index.md` and follows links, never hunts loose files. Reuse an existing topical page if one already covers the topic (don't fragment).

**Rules:**
- Stay **inside** `docs/setup/` (root), `docs/maintainer/`, `docs/sql/` — never write `docs/setup/swift/` or `docs/setup/web/` (refresh-owned coding guidance), and never create the top-level area directories themselves.
- New file or existing, write **idempotently** — update in place, never duplicate; and link every new page from `index.md`.
- **Ground every edit in the actual diff / CI / code** — do not invent. Where an operational step (e.g. a rollback) is *inferred* rather than evidenced by the code, still write it but tag it `⚠️ inferred — verify` so anyone following the runbook under pressure knows to confirm it.

**Return:** `DOCS UPDATED: {comma-list of files written/created, e.g. setup/index.md, setup/stripe.md}` or `none`.

---

## PROMOTE — promote epic learnings into the architecture doc

Story-scoped discoveries accumulate in `docs/epics/epic-{N}-context.md` (written by code-review's epic-context pass) but die at the epic boundary — without promotion the next epic plans against a stale `docs/architecture.md`.

**Input:** the epic number `{N}` (→ `docs/epics/epic-{N}-context.md`).

If the context file is absent or has no `## Story {id} Learnings` blocks, **stop silently**.

Scan the learnings for **project-canonical** facts a future epic must plan against:
- Schema / table / migration realities that differ from what `architecture.md` describes
- New or changed services, modules, integration points, external contracts
- Cross-cutting invariants or constraints established this epic
- Architectural decisions made or reversed during implementation

Append the durable ones to `docs/architecture.md` under a `## Epic {N} — Implementation Learnings` heading (create the heading once, append under it), **idempotently** — skip anything already reflected there (match on the *fact*, not verbatim text, so this is safe to run more than once per epic). Also note schema-shaped learnings in `docs/sql/` and operational ones in `docs/maintainer/` when those exist.

Promote *project reality only* — never `docs/setup/*` guidance.

**Return:** count of learnings promoted.

---

## DRIFT — flag stale coding guidance (never auto-write)

The read-the-other-direction case: implementation revealed the **guidance itself** in `docs/setup/swift|web/` is wrong, stale, or contradicted by what the codebase consistently and intentionally does. (A one-off violation is a review finding, not drift.)

**Input:** the observed contradiction.

Do **not** edit `docs/setup/*` — it is external-sourced canon owned solely by `/refresh-swift` / `/refresh-web`. Emit a single advisory:

```
GUIDANCE DRIFT: docs/setup/{swift|web}/{file}.md — {what the guidance says vs. what the project does}.
Recommend: /refresh-{swift|web} (re-source from upstream) or a deliberate manual setup edit if this is an intended project deviation.
```

Skip silently if the guidance held.

**Return:** the advisory line, or `none`.

---

## Direct invocation (`/docs-sync`)

Derive the changed-file list with `git diff --name-only` against the last commit (or the merge-base of the current branch), then run **OPERATIONAL** over it and report what changed. Use this to catch the human guides up after manual work done outside the flywheel. To keep it off the session model, spawn **`lw-docs-sync`** (Haiku) with the derived file list rather than running inline (fallback: inline).
