---
type: regex
pattern: "MANUAL:[\\s\\S]*?(\\[(visual-judgment|device-only|sandbox-only|setup-unreachable)\\]|none — )"
match: contains
---
`MANUAL:` is present and every item is tagged with a why-tag, or explicitly `none — …`.
