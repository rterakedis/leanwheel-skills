---
type: regex
pattern: "FOLLOW-UP REVIEW\\W{0,3}\\s*no\\b"
match: contains
---
No patch was applied, so the arithmetic score is `no` — a `yes` would mean the reviewer applied or counted patches it was told not to apply.
