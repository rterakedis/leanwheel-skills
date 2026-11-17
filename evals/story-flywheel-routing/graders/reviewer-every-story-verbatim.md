---
type: regex
pattern: "=== SWIFT ===[\\s\\S]*?reviewer_runs=every-story\\s*\\|\\s*reviewer_prompt=handoff-verbatim[\\s\\S]*?=== WEB ===[\\s\\S]*reviewer_runs=every-story\\s*\\|\\s*reviewer_prompt=handoff-verbatim"
match: contains
---
The reviewer runs on every story, clean or not, and gets the developer's REVIEW HANDOFF verbatim (DD-75).
