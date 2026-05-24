---
name: investigate
description: Forensic investigation of a bug, incident, or unfamiliar code area. Use when the user says "investigate", "debug", "trace this bug", or "help me understand this area before I work on it".
---

# Investigate Skill

**Goal:** Reconstruct from evidence; produce case file for cold handoff. Never fix until cause confirmed.

**Two modes:** Defect (symptom → root cause) | Exploration (understand area, find gotchas).

## Activation

1. Ask: "What are we investigating?" (error, stack, ticket, log, file/module, description)
2. Determine mode from input.
3. Slug: ticket ID or short name (lowercase, hyphens). Check for existing `docs/investigations/{slug}.md`.
4. Initialize case file immediately (persistent state across interruptions).

## Evidence Grading

**Confirmed** (directly observed, cite path:line/timestamp/commit) | **Deduced** (from Confirmed, show chain) | **Hypothesized** (plausible, state what confirms/refutes).

Rules: anchor before theories; never delete hypotheses (update status + resolution); document evidence gaps; challenge user description (it's a hypothesis).

## Execution

**Defect Mode:**
1. Anchor: one Confirmed piece of evidence. If sparse, go to evidence-light.
2. Standard trace: call paths, recent changes, specific file sections (parallel reads where independent). OR evidence-light: map what should happen, list plausible causes, identify confirmation path.
3. Triage hypotheses: Open/Confirmed/Refuted with evidence + resolution.
4. Root cause: state explicitly, explain symptom, note contributing factors.
5. Handoff: remediation (what, where, story vs. quick patch). Don't implement.

**Exploration Mode:**
1. Surface scan: entry points, interfaces (no implementation yet).
2. Mental model: what it owns, depends on, who depends on it.
3. Gotcha sweep: side effects, assumptions, fragility, safety warnings.
4. Handoff: summary with "Safe to touch" / "Handle with care" / "Do not touch without understanding X".

## Case File Format

Write to `docs/investigations/{slug}.md`:

```markdown
# Investigation: {slug}
Mode: Defect | Exploration | Status: Open | Resolved

## Input
{What user provided}

## Findings
### {title}
Grade: Confirmed | Deduced | Hypothesized
Status: Open | Confirmed | Refuted
Evidence: {path:line or timestamp}
Resolution: {if not Open}

## Hypotheses
| # | Hypothesis | Status | Evidence | Resolution |
|---|-----------|--------|----------|-----------|
| H1 | {desc} | Open | {anchor} | |

## Root Cause
{One paragraph when confirmed}

## Remediation
{What to fix, where, how}

## Exploration Notes
{Mental model, gotchas, safety assessment}
```

## After Investigation

Small patch: recommend `/quick-dev`.
New story: execute **SCHEDULE** from `skills/deferred/skill.md` (adds to earliest epic).
Pre-existing: add `[ ] [Defer]` to relevant story/spec.
Always leave case file continuable cold.
