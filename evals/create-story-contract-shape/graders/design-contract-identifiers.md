---
type: regex
target: { source: file, path: docs/epics/1-1-send-invoice.md }
pattern: "### Design Contract[\\s\\S]*?Accessibility identifiers?[^\\n:]*:?\\*{0,2}:?[\\s\\S]{0,600}?\\binvoice-[a-z-]+-(button|banner|badge|label|view|row)"
match: contains
---
A `### Design Contract` exists although the project has no `docs/ux/`, and names kebab-case `{feature}-{element}-{role}` accessibility identifiers (testability contract, DD-52).
