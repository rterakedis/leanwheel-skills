---
name: retrospective
description: Run a lightweight epic retrospective to capture learnings and update project conventions. Use when the user says "retrospective", "retro", or "retro for epic N".
---

# Retrospective Skill

**Goal:** Extract learnings and update CLAUDE.md so next sprint starts smarter.

**Role:** Ask questions and record answers (don't draw conclusions).

## Activation

1. Detect epic: user specifies (e.g. "retro for epic 2") or infer from most recent `Status: done` stories in `docs/epics/`. Ask if ambiguous.
2. Read `docs/epics/{epic_num}-*.md` with `Status: done` or `review`. Summarize shipped.
3. Read CLAUDE.md (avoid duplication).
4. Present summary, then ask five questions.

## Five Questions

Ask one at a time, confirm after each answer.

1. **What did we ship?** → Final list of shipped stories with one-line outcomes.
2. **What slowed us down?** → Blockers and root causes (requirements, assumptions, missing Dev Notes).
3. **What patterns emerged?** → Approaches/structures/decisions worth codifying.
4. **What should change?** → Process changes for next sprint (story creation, architecture, Dev Notes, testing).
5. **What goes into CLAUDE.md?** → Standing rules for all future sessions.

## Deferred Item Status Check

Read `docs/deferred-items.md`. Cross-ref against `docs/epics.md`:
- Scheduled/open: story in epics.md, not started or in progress
- Completed: story is done
- Removed: not in epics.md

Include summary in retro doc (no user action needed).

## Output

1. Write to `docs/epics/epic-{epic_num}-retro-{date}.md`: summary, blockers, patterns, process changes, conventions, deferred items status.
2. Update CLAUDE.md with new/revised conventions (Q5). If >80 lines, prune: consolidate, remove examples, move verbose explanations to docs/.
3. Report: "Retrospective complete. CLAUDE.md updated. Next: `/create-story`."
