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

Also read `docs/ux/DESIGN.md` and `docs/ux/EXPERIENCE.md` if present (needed for Check 9).

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

## Check 7 — Cross-Epic Runtime Dependencies

For every epic pair (A scheduled before B), ask: does any story in A require a runtime artifact — migration, seed data row, table, API endpoint — produced by a story in B to be end-to-end testable or operationally complete?

For each dependency found:
- **If B is scheduled after A and the artifact is required at A's runtime:** flag as a **blocker** — either reorder (pull the artifact story into A or before A), or explicitly annotate both epics with "Story A-N is operationally incomplete until Story B-M ships."
- **If B is scheduled after A but the artifact is only needed post-MVP or for optional flows:** flag as a **warning** — annotate the dependency, don't reorder.

Concrete examples to look for:
- Bootstrap/seed stories that produce a user or tenant row required by a later permission model
- Auth epics whose "first login" path depends on tenant data only created in a later onboarding epic
- Feature stories that JOIN against a table introduced in a later data-model story

---

## Check 8 — Testing Targets

Read `docs/architecture.md` to identify the tech stack, layers, and component types. From that, determine:

**What to test (include):** Business logic, state management, service/repository layers, data transformations, API clients, utility functions, anything with branching logic or non-trivial state.

**What to skip (exclude):** UI/view layer components that are pure layout (e.g., SwiftUI Views, React presentational components), generated code, third-party wrappers with no logic, boilerplate glue code. Derive these exclusions from the architecture's tech stack — a SwiftUI app excludes Views; a React app excludes pure presentational components; etc.

**Coverage target:** Based on the architecture, propose a meaningful percentage:
- Heavy business logic / domain model: 80%+
- Balanced app with service + UI layers: 60–75%
- Mostly UI-driven with thin logic: 40–60%
- Adjust up if architecture calls out safety, financial, or auth-critical paths

**Codify in CLAUDE.md:** Append the following to the `## Conventions` section of `CLAUDE.md` (create the section if missing):

```
### Testing
- Test targets: {list what to test, derived from architecture}
- Exclude from coverage: {list what to skip, derived from architecture}
- Coverage target: {N}% (measured against testable targets only)
```

If `CLAUDE.md` doesn't exist, note this as a warning but do not create it — that is the `/setup` skill's job.

---

## Check 9 — UX Alignment (conditional)

Run only if `docs/ux/DESIGN.md` or `docs/ux/EXPERIENCE.md` exists. If the product has user-visible UI but neither file exists, emit a warning: "UI stories planned with no design contract — run `/ux` or accept ad-hoc design."

- **Design status:** DESIGN.md and EXPERIENCE.md are `status: final` before the first UI story is implemented. Draft status = warning; unresolved `[OPEN]` HIG items = blocker for the stories they affect.
- **Surface coverage:** every story that builds user-visible UI maps to a named surface/flow in EXPERIENCE.md. A UI story with no EXPERIENCE.md coverage is a **blocker** — `/create-story` will have nothing to extract into the Design Contract, and the dev session will improvise.
- **State coverage:** surfaces being built this epic have empty/loading/error states defined (or explicit N/A). Missing = warning.
- **Token readiness:** DESIGN.md frontmatter has explicit values (hex, scale) for the tokens those surfaces consume — no empty-string tokens on load-bearing colors. Missing = blocker for affected stories.

---

## Output

Readiness report: nine checks, blockers (fix before `/create-story`), warnings (fix before epic).

Blockers: uncovered FRs, circular deps, architecture contradictions, cross-epic runtime blockers, UI stories without design coverage, empty load-bearing tokens. Call **LOG-AND-SCHEDULE** for remediation stories.
Warnings: weak ACs, scope overlap, missing security ACs, cross-epic runtime warnings, draft-status design specs, missing state coverage. Surface to user.
Testing targets written to `CLAUDE.md` Conventions section as part of this check.
