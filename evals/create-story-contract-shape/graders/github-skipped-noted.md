---
type: regex
pattern: "(github|\\bgh\\b)[^\\n]*(skip|unavailable|(not|n't) (installed|available|run|updated|created))|(skip|unavailable)[^\\n]*(github|\\bgh\\b)"
flags: i
match: contains
---
`GitHub unavailable, skip and note` — the final message says tracking was skipped.
