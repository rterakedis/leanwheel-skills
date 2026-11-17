---
type: regex
pattern: "=== WEB ===[\\s\\S]*?PHASE 1\\s*\\|\\s*agent=lw-story-creator\\s*\\|\\s*model=sonnet\\s*\\|\\s*effort=medium\\s*\\|\\s*spawn_model_param=omit[\\s\\S]*?PHASE 2\\s*\\|\\s*agent=lw-story-developer\\s*\\|\\s*model=sonnet\\s*\\|\\s*effort=high\\s*\\|\\s*spawn_model_param=omit[\\s\\S]*?PHASE 3\\s*\\|\\s*agent=lw-story-reviewer\\s*\\|\\s*model=sonnet\\s*\\|\\s*effort=high\\s*\\|\\s*spawn_model_param=omit"
match: contains
---
Web: the Opus override is Swift-only, so the developer stays pinned Sonnet with no model param.
