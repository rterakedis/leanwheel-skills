---
name: discover
description: Reverse-engineer a brownfield project into docs/prd.md, docs/architecture.md, and CLAUDE.md. Use when the user says "discover project", "document this codebase", or is starting a new AI-assisted workflow on an existing project.
---

# Discover Skill

**Goal:** Produce `docs/prd.md`, `docs/architecture.md`, `CLAUDE.md` from existing codebase.

**Brownfield:** PRD documents current state (FRs = existing behavior). Plan new work via `/epics` or `/quick-dev`.

## Activation

Scan project root. Read key files silently: README, package.json (or equiv), config, Makefile/docker-compose, existing docs/, CLAUDE.md.

Greet: "I see {language/framework}. Found {key files}. Need questions then generate docs."

## Phase 1 — Product Interview

Five questions, one at a time:

1. What does this product do? (problem, users, main capabilities)
2. Current state? (production/dev, completeness)
3. Explicitly out of scope? (Non-Goals)
4. Non-obvious architectural decisions? (why certain choices, unusual patterns)
5. Common mistakes or footguns? (past bugs, patterns that look right but break)

## Phase 2 — Codebase Analysis

**Tech stack:** language, runtime, framework, libs, database, auth, testing, build/deploy.
**Folder structure:** top-level layout, features/modules, tests.
**Patterns:** naming, feature structure, error handling, test approach, standard imports/utilities.
**Current capabilities:** routes/endpoints, data model, integrations.

## Phase 3 — Write `docs/architecture.md`

Use template. Fill from Phase 2 + interview. Priority: Tech Stack (exact versions), Folder Structure (annotated), Key Patterns (especially from Q4), Testing Strategy.

Write to `docs/architecture.md`.

## Phase 4 — Write `docs/prd.md`

Use template. Sections: Vision (Q1), Target User, Glossary (from code), Features (current behavior from routes/controllers/Q1), Non-Goals (Q3), MVP Scope (exists=In, gaps=Out), Success Metrics (or "Not yet defined").

Write to `docs/prd.md`.

## Phase 5 — Write `CLAUDE.md`

Structure: What This Project Is (one-para), Docs (paths), Critical Rules (Q4+Q5+analysis, with why), Conventions, Known Footguns (Q5).

Write to root. If exists, merge (show diff).

## Phase 6 — Done

Report: "{N} FRs, {M} features in PRD. Tech stack + patterns in architecture. {N} rules + {M} footguns in CLAUDE.md.

Next: `/security-review` (audit existing), `/epics` (new features), or `/quick-dev` (one-off)."
