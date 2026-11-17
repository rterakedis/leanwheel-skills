---
type: regex
pattern: "DOCS-SYNC[^\\n]*agent=lw-docs-sync\\s*\\|\\s*model=haiku\\s*\\|\\s*effort=low[\\s\\S]*DOCS-SYNC[^\\n]*agent=lw-docs-sync\\s*\\|\\s*model=haiku\\s*\\|\\s*effort=low"
match: contains
---
Both blocks route operational doc sync to lw-docs-sync on Haiku at low effort.
