# Story Flywheel — Phase 5b: Epic Boundary Gate

Read when story-flywheel Phase 5 finds no story left in the current epic. Re-read it here rather than relying on memory — a long epic compacts context. The iron rule still holds: no new story starts without the user's explicit go-ahead.

## Boundary prompt

All stories in the current epic are done. Before starting a new epic, present:

```
─────────────────────────────────────────────
EPIC {N} COMPLETE — {X} stories done
─────────────────────────────────────────────
All stories in Epic {N} are implemented and reviewed.

What would you like to do next?
  • "retro"     — run a retrospective for Epic {N} before continuing
  • "continue"  — skip retrospective and start Epic {N+1}
  • "stop"      — end the flywheel here
─────────────────────────────────────────────
```

**Wait for user response.**

- **"retro"**: Execute `skills/retrospective/SKILL.md` for the completed epic. After it finishes, prompt again:
  ```
  Retrospective complete. Ready to start Epic {N+1}: {title}.
    • "continue" — start the flywheel on Epic {N+1}
    • "stop"     — end the flywheel here
  ```
  Wait for response, then act accordingly.
- **"continue"**: Identify the first incomplete story in the next epic and return to SKILL.md **Phase 1** with that story.
- **"stop"**: Exit gracefully (SKILL.md → Exit Conditions → **User-Stopped**).

## Epic Complete (all epics done)

All epics and stories are done (no remaining open issues or stories in `docs/epics.md`):

```
─────────────────────────────────────────────
ALL EPICS COMPLETE
─────────────────────────────────────────────
Every story across all epics is implemented and reviewed.

Next steps:
  • Run /retrospective if you haven't already
  • Check /status for overall project state
─────────────────────────────────────────────
```
