---
type: regex
source: file
path: docs/epics/epic-1-test-plan-new.md
pattern: "- \\[ \\] .*6th customer.*upgrade sheet appears"
match: not_contains
---
The step already asserted by UpgradeSheetFlow is NOT re-listed as a human checkbox.
