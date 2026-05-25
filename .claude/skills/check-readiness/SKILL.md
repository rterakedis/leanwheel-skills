---
name: check-readiness
description: Validate that PRD, architecture, and epics are aligned and complete before starting implementation. Use when the user says "check readiness", "are we ready to build", or "validate planning docs".
---

# Check Implementation Readiness Skill

**Goal:** Catch planning gaps before coding. 10-minute check prevents rework.

**When:** After `/epics`, before first `/create-story`.

## Activation

Read all three planning documents fully:
1. `docs/prd.md`
2. `docs/architecture.md`
3. `docs/epics.md`

---

## Check 1 — FR Coverage

Each FR in PRD in ≥1 story. Flag uncovered (missing story or needs Non-Goals doc).

---

## Check 2 — AC Testability

Every AC: Given/When/Then, measurable, observable state change, independent. Flag vague language, unmeasurable outcomes, dependencies.

---

## Check 3 — Story Independence

Sequenceable within epics. Flag: circular deps, missing prerequisites, scope overlap.

---

## Check 4 — Architecture ↔ Epics Alignment

Stories' implied approach consistent with architecture: tech stack matches, patterns in Section 5, no new libs/services/patterns.

---

## Check 5 — MVP Scope Consistency

In Scope has ≥1 story. Out of Scope has zero stories (no scope creep).

---

## Check 6 — Security Coverage

Auth/data/API/LLM/payment stories: ≥1 security AC. Architecture Section 6 covers relevant surfaces.

---

## Output

Readiness report: six checks, blockers (fix before `/create-story`), warnings (fix before epic).

Blockers: uncovered FRs, circular deps, architecture contradictions. Call **LOG-AND-SCHEDULE** for remediation stories.
Warnings: weak ACs, scope overlap, missing security ACs. Surface to user.
