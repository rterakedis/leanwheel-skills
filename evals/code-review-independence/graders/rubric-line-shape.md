---
type: regex
pattern: "RUBRIC\\W{0,4}\\s*correctness\\s+(PASS|FAIL)[^\\n]*edge-cases\\s+(PASS|FAIL)[^\\n]*ac-coverage\\s+(PASS|FAIL)[^\\n]*design\\s+(PASS|FAIL|n/a)[^\\n]*simplicity\\s+(PASS|FAIL)[^\\n]*security\\s+(PASS|FAIL|n/a)[^\\n]*GATE\\s+(PASS|FAIL)"
match: contains
---
The scored rubric line carries every dimension in the contract order and ends with a GATE verdict, all on one line.
