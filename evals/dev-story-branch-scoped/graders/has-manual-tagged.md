---
type: regex
pattern: "MANUAL:[\\s\\S]*?(\\[(visual-judgment|device-only|sandbox-only|setup-unreachable)\\]|none — )"
match: contains
---
`MANUAL:` is present and tagged, or explicitly `none — …`.
