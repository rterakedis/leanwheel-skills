---
epic: {epic}
story: {story}
github_issue: 0
---

# Story {epic}.{story}: {title}

**Status:** ready-for-dev

## Story

As a {role},
I want {action},
so that {benefit}.

**Satisfies:** {FR-N, FR-M} | **Enables:** {UJ-N}

## Acceptance Criteria

1. **Given** {context} **when** {action} **then** {outcome}
2. **Given** … **when** … **then** …

## Tasks / Subtasks

- [ ] Task 1: {specific action on specific file} (AC: 1)
  - [ ] Subtask 1.1
  - [ ] Subtask 1.2
- [ ] Task 2: … (AC: 2)
  - [ ] Subtask 2.1
- [ ] Task 3: Write tests
  - [ ] Unit test for {component}
  - [ ] Integration test for {flow}

## Dev Notes

### Security Sensitivity
*Set by `/create-story`. Leave blank if none apply. Present = Pass D runs automatically during inline review.*
- **Categories:** {none | auth | data-access | api | secrets | llm | payments | file-upload}

### Architecture Constraints
*Extracted from docs/architecture.md — embed the relevant rules here, do not reference by location only.*

- **Convention N:** {rule} — {why it applies to this story}
- **Banned pattern:** {pattern} — use {alternative} instead

### Files to Touch
| File | Action | Notes |
|------|--------|-------|
| `{path}` | Create / Modify / Delete | {what changes} |

### Key Implementation Details
- {Library/framework to use and version if specified}
- {Specific API or integration behavior}
- {Data model fields that must be present}
- {Error conditions that must be handled}

### Design Contract
*UI stories only — extracted from docs/ux/ by `/create-story`. Omit this section for stories with no user-visible surface.*

- **Tokens:** {token: value pairs this UI consumes}
- **Components:** {component → spec summary; SwiftUI view / element mapping}
- **Required states:** {surface → empty / loading / error specs}
- **Reuse (do not recreate):** {components from docs/ux/components-built.md}
- **Platform checklist:** {applicable HIG / web guardrail items}

### Prior Story Context
*What earlier stories established that this story must not break:*
- {Pattern or file established in story X that we must follow}

### Testing Requirements
Per the testing strategy in docs/architecture.md:
- Unit: {what to test, framework}
- Integration: {what to test, if applicable}

### References
- `docs/prd.md` §{section} — {what was extracted}
- `docs/architecture.md` §{section} — {what was extracted}
- `docs/epics.md` Epic {N}, Story {M} — source story spec

## Dev Agent Record

### Agent Model
{model used}

### Debug Log
*Keep the 5 most recent entries. Summarize older ones into a single "Prior issues" row if needed.*

| Issue | Resolution |
|-------|-----------|

### Completion Notes

### File List
*All files created, modified, or deleted:*
- `{path}` — {created | modified | deleted}

### Change Log
- {date}: {what changed and why}
