---
type: regex
target: { source: file, path: docs/epics/1-1-send-invoice.md }
pattern: "^-{3}\\n(?:(?!-{3}\\n)[^\\n]*\\n)*?status: ready-for-dev\\n"
match: contains
---
`status: ready-for-dev` sits inside the YAML frontmatter (the machine-readable source of truth, DD-51) — not left as a template default elsewhere or dropped.
