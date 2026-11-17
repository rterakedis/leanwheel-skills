---
name: docs-sync-operational
tags: [docs-sync, contract, haiku]
model: haiku
runs: 1
max_turns: 25
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write, Edit]
---
Run /docs-sync OPERATIONAL for story docs/epics/3-2-webhook-events.md in the project in the current working directory. Its File List is the changed-file set. You cannot spawn a subagent here, so run the op inline. Finish with the op's return line.
