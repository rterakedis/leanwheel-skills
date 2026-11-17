---
type: regex
target: { source: file, path: docs/epics/1-1-send-invoice.md }
pattern: "### Behavior Contract[\\s\\S]*?Invariants[^\\n:]*(?::\\*\\*|\\*\\*:|:)\\s*[^\\s{*]"
match: contains
---
A stateful story gets a real `### Behavior Contract` whose Invariants line is filled in (not the `{placeholder}` and not omitted) — dev-story verifies each listed invariant with evidence.
