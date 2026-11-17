---
type: regex
target: { source: file, path: docs/setup/index.md }
pattern: "WEBHOOK_SIGNING_SECRET"
match: contains
---
The env step in `docs/setup/index.md` lists the new var too (the table's "resources.md + the env step in index.md").
