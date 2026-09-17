---
type: regex
pattern: "REVIEW HANDOFF[\\s\\S]*?STORY:\\s*\\S[\\s\\S]*?BASE:\\s*[0-9a-f]{7,40}\\b"
match: contains
---
The report hands off to the independent reviewer with the `STORY:` and `BASE:` pointers (DD-75).
