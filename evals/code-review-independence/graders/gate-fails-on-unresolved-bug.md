---
type: regex
pattern: "RUBRIC\\W{0,4}[^\\n]*correctness\\s+FAIL[^\\n]*GATE\\s+FAIL"
match: contains
---
An unresolved `[ ]` correctness finding makes the correctness dimension and the GATE FAIL (SCORE rule: a dimension is FAIL if any unresolved finding maps to it).
