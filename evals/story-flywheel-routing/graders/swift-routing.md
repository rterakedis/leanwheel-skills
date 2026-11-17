---
type: regex
pattern: "=== SWIFT ===[\\s\\S]*?PHASE 1\\s*\\|\\s*agent=lw-story-creator\\s*\\|\\s*model=sonnet\\s*\\|\\s*effort=medium\\s*\\|\\s*spawn_model_param=omit[\\s\\S]*?PHASE 2\\s*\\|\\s*agent=lw-story-developer\\s*\\|\\s*model=opus\\s*\\|\\s*effort=high\\s*\\|\\s*spawn_model_param=opus[\\s\\S]*?PHASE 3\\s*\\|\\s*agent=lw-story-reviewer\\s*\\|\\s*model=sonnet\\s*\\|\\s*effort=high\\s*\\|\\s*spawn_model_param=omit[\\s\\S]*?=== WEB ==="
match: contains
---
Swift: creator sonnet/medium, developer opus/high with an explicit opus spawn override, reviewer sonnet/high, nothing else overridden.
