---
name: story-flywheel-routing
tags: [story-flywheel, routing, progressive-disclosure, contract]
runs: 1
max_turns: 10
timeout_seconds: 300
---
You are the `/story-flywheel` orchestrator at Activation for Epic 2. Use the story-flywheel skill. The leanwheel subagents (`lw-story-creator`, `lw-story-developer`, `lw-story-reviewer`, `lw-docs-sync`) ARE available. The user has NOT pre-authorized auto-continue. Do not look at any project files, run any command, or call the Agent tool: spawn nothing and stop after answering.

Decide the delegation routing the skill prescribes for two hypothetical projects: (a) a Swift project (`docs/setup/swift/` exists) and (b) a web project (`package.json`, no Apple project files). Output ONLY the following template, filled in, with no other text. Allowed values: model = sonnet|opus|haiku|fable; effort = low|medium|high; spawn_model_param = the `model` argument you would pass on that Agent call, or `omit` if you would pass none; reviewer_runs = every-story|only-when-issues; reviewer_prompt = handoff-verbatim|handoff-plus-summary.

=== SWIFT ===
PHASE 1 | agent=<subagent_type> | model=<m> | effort=<e> | spawn_model_param=<p>
PHASE 2 | agent=<subagent_type> | model=<m> | effort=<e> | spawn_model_param=<p>
PHASE 3 | agent=<subagent_type> | model=<m> | effort=<e> | spawn_model_param=<p>
DOCS-SYNC (only when INFRA TOUCHED: yes) | agent=<subagent_type> | model=<m> | effort=<e>
reviewer_runs=<v> | reviewer_prompt=<v>
=== WEB ===
PHASE 1 | agent=<subagent_type> | model=<m> | effort=<e> | spawn_model_param=<p>
PHASE 2 | agent=<subagent_type> | model=<m> | effort=<e> | spawn_model_param=<p>
PHASE 3 | agent=<subagent_type> | model=<m> | effort=<e> | spawn_model_param=<p>
DOCS-SYNC (only when INFRA TOUCHED: yes) | agent=<subagent_type> | model=<m> | effort=<e>
reviewer_runs=<v> | reviewer_prompt=<v>
