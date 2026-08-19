---
type: regex
source: file
path: docs/epics.md
pattern: "- \\[x\\] .*already automated.*\\*\\*plan-defect\\*\\*"
match: contains
---
The "already automated" note is logged as a pre-checked `plan-defect` row in the Post-Test Findings block.
