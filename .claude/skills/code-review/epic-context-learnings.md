# Epic-context learnings — read only when a story file was loaded and `docs/epics/epic-<n>-context.md` exists

Applied from Step 5 → *Update epic context*, before updating status.

1. Check for discoveries made during review or fix application that future stories/epics should know about:
   - Constraints or invariants uncovered while fixing bugs
   - Schema, API, or integration details that differed from assumptions
   - Patterns established or broken during patches
   - Any "we learned X the hard way" that isn't obvious from the code
2. Discoveries exist → append them to `docs/epics/epic-<n>-context.md` under a `## Story {id} Learnings` heading. These project-canonical learnings are promoted into `docs/architecture.md` at the epic boundary by `/epic-flywheel`.
3. No discoveries worth capturing → skip silently.
