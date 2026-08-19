---
type: regex
source: file
path: docs/epics/epic-1-test-plan-new.md
pattern: "sim\\.sh launch[^\\n]*--uitest[^\\n]*--seed"
match: contains
---
The Starting state carries a launch command with its companion flags, not a bare flag.
