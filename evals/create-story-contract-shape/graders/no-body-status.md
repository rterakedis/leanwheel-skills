---
type: regex
target: { source: file, path: docs/epics/1-1-send-invoice.md }
pattern: "^\\s*(\\*\\*)?Status:?(\\*\\*)?:?\\s"
flags: m
match: not_contains
---
No body `**Status:**` / `Status:` line at the start of a line (case-sensitive; the lowercase frontmatter `status:` does not match).
