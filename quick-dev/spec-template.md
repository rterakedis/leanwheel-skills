---
title: '{short descriptive title}'
type: feature  # feature | bugfix | refactor | chore
created: '{date}'
status: draft  # draft | approved | in-progress | done
---

## Intent

**Problem:** {What is broken or missing, and why it matters. 1–2 sentences.}

**Approach:** {The high-level "what", not the "how". 1–2 sentences.}

---
*Frozen after user approval — do not modify Intent or Boundaries during implementation.*

## Boundaries

**Always:** {Invariant rules this implementation must follow — architecture conventions, security requirements, patterns that must not be broken.}

**Ask First:** {Decisions that require human input before proceeding — ambiguous behavior, data migration risk, breaking changes to existing APIs.}

**Never:** {What this change explicitly does not do. Out-of-scope items. Forbidden approaches.}

## I/O & Edge Cases

*Delete this section entirely if there are no meaningful input/output scenarios.*

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Happy path | | | N/A |
| Error case | | | |

## Code Map

*Files relevant to this change. Populated during planning — prevents blind codebase searching.*

- `{path}` — {role or what changes here}
- `{path}` — {role or what changes here}

## Tasks

*Each task: backtick-quoted file path — action — rationale. One task per file unless changes are tightly coupled.*

- [ ] `{path}` — {action} — {why}
- [ ] `{path}` — {action} — {why}
- [ ] `{path}` — add/update tests for {what}

## Acceptance Criteria

*System-level behaviors. Do not duplicate I/O matrix rows here.*

- Given {context}, when {action}, then {outcome}
- Given {context}, when {action}, then {outcome}

## Verification

*Delete this section if no CLI verification applies.*

- `{command}` — expected: {success criteria}
- `{command}` — expected: {success criteria}
