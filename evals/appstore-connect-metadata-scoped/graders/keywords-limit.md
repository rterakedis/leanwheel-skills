---
type: regex
source: file
path: docs/store/metadata/en-US/keywords.txt
pattern: "^[^ ]{1,100}\\s*$"
match: contains
---
keywords.txt was written: at most 100 characters, comma-separated without spaces (a rule that now lives only in op-metadata.md).
