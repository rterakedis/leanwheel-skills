# Story Flywheel — Auto-pilot

Read when the user pre-authorizes "auto-continue on clean stories". Re-read it after any context compaction. Default (no pre-authorization): pause at every Phase 4 checkpoint.

- A story with no `UNRESOLVED` items, a PASS gate, a green Build & Test, and (Swift) `FINAL CYCLE: green` advances without waiting for "continue" (commits only if also pre-authorized).
- Unresolved items, a FAIL gate, a red build, or a HALT always stop for the human.
- The story-level ledger roll-up (SKILL.md → Phase 4 → **Observability**) is still written for every auto-advanced story.
- `/epic-flywheel` makes this the default within an epic.
