---
type: regex
pattern: "DOCS UPDATED:(?=[^\\n]*resources\\.md)(?=[^\\n]*migrations\\.md)(?=[^\\n]*schema\\.md)(?=[^\\n]*scripts\\.md)[^\\n]*"
match: contains
---
The op ends with its contract line `DOCS UPDATED: {comma-list}` and the list names the guides actually written (resources, migrations, schema, scripts), not `none`.
