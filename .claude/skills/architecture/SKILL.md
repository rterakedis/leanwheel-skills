---
name: architecture
description: Create or update the technical architecture document. Use when the user says "create architecture" or "update architecture".
---

# Architecture Skill

**Goal:** Produce an architecture document that gives every dev session consistent, unambiguous implementation guidance.

**Your role:** Architectural peer collaborating with the user — you bring structure, they bring domain knowledge and preferences.

## Activation

1. Check for `docs/architecture.md` (update vs. create).
2. Read `docs/prd.md` (required). Stop if missing; tell user to run `/prd` first.
3. Read `docs/epics.md` if present.
4. Read `docs/project/` for technical inputs (ADRs, research, vendor evaluations, API docs).
5. Confirm with user: "Found: [list]. Anything else before we start?"

## Workflow

Work through each section below in order. For each section:
- Show your current understanding and any assumptions
- Ask the user to confirm, correct, or expand
- Only write the section after the user has confirmed
- Do not proceed to the next section until the user explicitly says to continue

### Section 1 — Tech Stack
- Primary language, runtime, version constraints?
- Frontend framework?
- Database(s) — type, product, hosting?
- Key third-party services?
- Deployment target?

Output: bulleted decisions with one-line rationale.

### Section 2 — Data Model
- Core entities and relationships (from PRD Glossary)?
- Cardinalities for implementation?
- Sensitive data needing special handling?

Output: entities with fields and relationships (prose or table).

### Section 3 — API / Integration Design
- Internal API style (REST, GraphQL, tRPC, RPC)?
- Authentication?
- External integrations and call patterns?
- Error contract conventions?

Output: API conventions; list endpoints/mutations/subscriptions (non-obvious shapes).

### Section 4 — Project Structure
- Monorepo or polyrepo?
- Top-level folder layout?
- Where do features/modules live?
- Naming conventions?

Output: annotated folder tree.

### Section 5 — Key Patterns and Conventions
- State management (client and server)?
- Business logic separation from UI/transport?
- Error handling pattern?
- Logging and observability?
- Banned patterns?

Output: numbered conventions (rules for dev sessions).

### Section 6 — Testing Strategy
- Unit test framework and scope?
- Integration test approach?
- E2E test scope?
- CI gate requirements?

Output: testing matrix (scope → tool → coverage).

## Finalize

1. Write to `docs/architecture.md` using template.
2. Scan `docs/epics/` for `Status: in-progress` or `done`. If found: "Run `/correct-course` to assess pattern changes. Affected: {list}."
3. Otherwise: next step is `/epics` or `/check-readiness`.
