# Standalone run — read only when you are NOT running as the `lw-story-developer` subagent

Applied from On Completion step 3. Under a flywheel none of this applies: you report `INFRA TOUCHED` and stop after the report.

## Operational doc sync (step 3.2)

Spawn `subagent_type: "lw-docs-sync"` yourself with op **OPERATIONAL** and the story path. No subagents → execute **OPERATIONAL** from `skills/docs-sync/SKILL.md` inline. Record any `DOCS UPDATED` in the Debug Log.

## Start the review (step 3.5)

1. Call the Agent tool with `subagent_type: "lw-story-reviewer"` and the REVIEW HANDOFF block as the prompt, and relay its report.
2. It cannot ask the user: put its `DECISIONS NEEDED` to the user and send the answers back to the same reviewer.
3. Subagents unavailable → tell the user to `/clear` and run `/code-review {story path}` — never review in this context.
