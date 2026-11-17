---
type: tool_used
tool: Bash
input_match: "(>>?|\\btee\\b|sed -i|\\bmv\\b|\\brm\\b|\\bcp\\b)[^\\n|]*docs/setup/(swift|web)"
min: 0
max: 0
arm: both
---
Same hard rule, via the shell (redirect, tee, sed -i, mv, rm, cp aimed at the guidance dirs). Plain reads do not match.
