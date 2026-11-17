---
name: create-story-contract-shape
tags: [create-story, contract]
runs: 1
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write, Edit]
---
Run /create-story 1-1 against the project in the current working directory. Yes, create story 1-1: Send invoice. Write it to docs/epics/1-1-send-invoice.md.

Every decision for this story is already recorded in its docs/epics.md entry, so there are no material ambiguities: pass the Clarification Gate without asking anything, and record any default you pick as a stated assumption in the story. Treat this message as the user's review approval too: after writing, complete the post-approval steps in the same run (set `status: ready-for-dev` in the frontmatter, update the epic context cache). The `gh` CLI is not installed, so GitHub tracking is unavailable: skip it and say so in your final message. Do not ask me anything.
