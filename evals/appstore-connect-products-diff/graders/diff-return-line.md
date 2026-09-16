---
type: regex
pattern: "PRODUCTS DIFF: \\d+ mismatch(es)?, \\d+ recommendations?"
match: contains
---
The DIFF sub-op emits its contract line, which /appstore-preflight embeds in its checklist.
