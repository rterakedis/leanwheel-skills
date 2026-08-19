---
type: regex
source: file
path: docs/epics/epic-1-test-plan.md
pattern: "^\\s+[-*] (already automated|price line wraps)"
match: not_contains
---
The tester's inline finding bullets are stripped from the plan on reset.
