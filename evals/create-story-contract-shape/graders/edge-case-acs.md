---
type: regex
target: { source: file, path: docs/epics/1-1-send-invoice.md }
pattern: "## Acceptance Criteria[\\s\\S]*?(already sent|re-?send|twice|double|fail|retry|no line items|empty|in.flight)[\\s\\S]*?## Tasks / Subtasks"
flags: i
match: contains
---
The Acceptance Criteria section (between its heading and `## Tasks / Subtasks`) contains edge-case ACs — failure/retry, empty draft, double-send — not just the one happy-path AC copied from epics.md.
