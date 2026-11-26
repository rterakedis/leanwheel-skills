# Story Flywheel — Fallback: subagents unavailable

Read when story-flywheel Activation step 4 finds the leanwheel subagents (`lw-story-creator`, `lw-story-developer`, `lw-story-reviewer`, `lw-docs-sync`) unavailable. Re-read it after any context compaction. Everything not listed here — the loop order, gates, report fields, Phase 4 checkpoint, ledger roll-up, and the iron rule — is unchanged from SKILL.md.

## Model

- Run every phase inline on the **current session model**.
- Never prompt a `/model` or `/effort` switch — it busts the prompt cache, so a per-phase Sonnet→Opus→Sonnet dance costs more than it saves.
- If the user wants the Swift dev phase on a stronger model, say once at activation: "start the flywheel in a fresh session on {model} for this epic", and proceed on the current model if they decline.

## Per-phase inline equivalents

Inline phases execute `skills/create-story/SKILL.md`, `skills/dev-story/SKILL.md`, and `skills/code-review/SKILL.md` directly; the checkpoint, gates, and report fields are unchanged.

| Phase | Inline equivalent |
|---|---|
| 1 — Create Story | Execute `skills/create-story/SKILL.md` inline on the session model. |
| 2 — Dev Story | Run the `## Probe` first as usual, then execute `skills/dev-story/SKILL.md` inline on the session model. |
| 2 — Operational doc sync | When `INFRA TOUCHED: yes`, execute the docs-sync OPERATIONAL op inline. |
| 3 — Code Review | Execute `skills/code-review/SKILL.md` inline on the session model. That review shares the author's context, so record `review=inline-fallback` in the roll-up and say so at the checkpoint. |
| 3b — Final Cycle (Swift) | Unchanged — run [final-cycle.md](final-cycle.md) inline; its "spawn the developer" on red becomes an inline dev-story fix. |
