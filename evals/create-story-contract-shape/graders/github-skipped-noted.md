---
type: regex
pattern: "(github|\\bgh\\b)[^\\n]*(skip|unavailable|not (installed|available))|(skip|unavailable)[^\\n]*(github|\\bgh\\b)"
flags: i
match: contains
---
`GitHub unavailable, skip and note` — the final message says tracking was skipped.
