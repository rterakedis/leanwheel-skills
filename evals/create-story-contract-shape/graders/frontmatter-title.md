---
type: regex
target: { source: file, path: docs/epics/1-1-send-invoice.md }
pattern: "^-{3}\\n(?:(?!-{3}\\n)[^\\n]*\\n)*?title: \\S"
match: contains
---
`title:` is in the frontmatter with a non-empty value (the flywheels and github-tracking read it).
