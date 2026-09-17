---
type: regex
target: { source: file, path: docs/maintainer/appstore-submission-checklist.md }
pattern: "\\{omit if|if universal\\}"
match: not_contains
---
No unresolved conditional markers reach the written checklist.
