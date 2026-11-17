---
type: regex
target: { source: file, path: docs/epics/1-1-send-invoice.md }
pattern: "## Acceptance Criteria[\\s\\S]*## Tasks / Subtasks[\\s\\S]*## Dev Notes[\\s\\S]*### Security Sensitivity[\\s\\S]*## Dev Agent Record[\\s\\S]*### File List"
match: contains
---
The headings downstream skills parse exist and in template order: ACs, Tasks, Dev Notes, Security Sensitivity (code-review Pass B), `## Dev Agent Record` (code-review reads the story only up to it) and its `### File List` (lw-docs-sync reads it).
