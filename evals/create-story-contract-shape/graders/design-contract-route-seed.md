---
type: regex
target: { source: file, path: docs/epics/1-1-send-invoice.md }
pattern: "### Design Contract[\\s\\S]*?Deep-link route:?\\*{0,2}:?[^\\n]*planapp://[\\s\\S]*?Seed scenarios?(?::\\*\\*|\\*\\*:|:)\\s*[^\\s{*]"
match: contains
---
The Design Contract also names the deep-link route (`planapp://…`, from testability.md) and a seed scenario (DD-52). `Seed scenarios:` (plural) is accepted: a story that names several is correct, and the singular-only pattern failed about one run in four on it.
