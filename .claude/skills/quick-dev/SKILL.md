---
name: quick-dev
description: Implement a one-off feature, bugfix, or change without the full epic/story workflow. Keeps docs/prd.md and docs/architecture.md current. Use when the user says "quick dev", "add feature", "fix bug", or describes a change after the initial MVP is shipped.
---

# Quick Dev Skill

**Goal:** Implement one-off features/bugfixes that follow architecture and keep docs current.

**When:** Post-MVP one-offs where epic/story is overhead. Use full flywheel for large feature areas.

## Activation

1. Read `docs/architecture.md` (required constraint document).
2. Read `docs/prd.md` (what exists; don't duplicate/contradict).
3. Read `CLAUDE.md` if exists (project conventions).
4. Identify intent. If unclear: "What should this do, user-facing outcome?"

## Phase 1 — Scope Check

Single goal = one deliverable (cross-layer cross-layer work OK if serving one goal).
Multi-goal = split into separate runs.

If multi-goal, ask which to do first.

## Phase 2 — Write the Spec

Write to `docs/specs/{slug}.md` using template. Rules:
- Intent frozen after approval
- Boundaries (Always/Ask-First/Never) drive implementation
- I/O matrix optional (include only if needed)
- Tasks are file-level, specific actions
- ACs are system behaviors (not I/O duplicates)
- Target 900–1300 tokens

Get explicit approval before implementing.

## Phase 3 — Implement

For each task:
1. Implement.
2. Check off: `[ ]` → `[x]`.
3. If wrong assumption: update spec, don't silently deviate.

Stop only if: Ask-First boundary triggered, dependency missing, or requires out-of-scope changes risking breakage.

Run verification commands after all tasks done.

Security pass (conditional): If intent/files touch auth/data-access/api/secrets/llm/payments/file-upload, run matching categories from `skills/security-review/skill.md`. Call **LOG-AND-SCHEDULE** for critical/high findings.

## Phase 4 — Doc Update (mandatory)

**PRD:** New capability not in FR? Changed FR behavior? New non-goal? Update FRs with consequences, §9 Assumptions, add `<!-- updated: {date} -->`.

**Architecture:** New library/service? New pattern? Deviated from existing? Folder structure changed? Update sections, add new conventions to Section 5.

**CLAUDE.md:** Gotcha/footgun discovered? New project rule? Add it.

**Operational guides:** if this change touched an infra-shaped file (dependency, env var, migration, script, deploy/CI, new service), spawn **`bmad-docs-sync`** (Haiku) with op `OPERATIONAL` and the changed-file list to keep the human stand-up / run-it / database guides current — off the session model (fallback: execute the docs-sync **OPERATIONAL** op inline if subagents are unavailable). Zero-cost / skip when no infra file changed.

If no updates needed, confirm: "No doc updates required."

## Phase 5 — GitHub Tracking (optional)

If available: create and close issue with `--label "done"`. Add milestone only if belongs to epic. Skip if unavailable.
