---
title: '{short descriptive title}'
type: feature  # feature | bugfix | refactor | chore
created: '{date}'
status: draft  # draft | approved | in-progress | done
complexity: simple  # simple | stateful
---

## Intent

**Problem:** {What is broken or missing, and why it matters. 1–2 sentences.}

**Approach:** {The high-level "what", not the "how". 1–2 sentences.}

---
*Frozen after user approval — do not modify Intent or Boundaries during implementation.*

## Boundaries

**Always:** {Invariant rules this implementation must follow — conventions found in the host CLAUDE.md/AGENTS.md, security requirements, patterns that must not be broken.}

**Ask First:** {Decisions that require human input before proceeding — ambiguous behavior, data-loss risk, breaking changes to existing APIs.}

**Never:** {What this change explicitly does not do. Out-of-scope items. Forbidden approaches.}

## Behavior Contract

*Stateful goals only — carries the Phase 1 grilling. Collapse to one line or delete for simple goals.*

**Flows:** {each flow as a step sequence — happy path + every alternate path}

**States & transitions:** {valid transitions; illegal transitions that must be rejected}

**Edge cases:** {empty/boundary inputs · concurrent/duplicate actions · partial failure & retry · offline/timeout · permission edges · first-run vs returning}

**Invariants:**
- [ ] {must always hold} — {evidence recorded at the Build & Test Gate: test name or file:line}

**Stated assumptions:** {ambiguities resolved with a sensible default, recorded so the user can correct them}

## Code Map

*Files relevant to this change. Populated during planning — prevents blind codebase searching.*

- `{path}` — {role or what changes here}

## Tasks

*Each task: backtick-quoted file path — action — rationale. One task per file unless changes are tightly coupled.*

- [ ] `{path}` — {action} — {why}
- [ ] `{path}` — add/update tests for {what}

## Acceptance Criteria

*Given/When/Then, independently testable. Every material edge case from the Behavior Contract gets its own AC.*

- [ ] Given {context}, when {action}, then {outcome}

## Verification

*The exact commands the Build & Test Gate runs. If no toolchain exists, the manual-required note lands here.*

- `{command}` — expected: {success criteria}
