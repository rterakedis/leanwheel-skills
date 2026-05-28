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
3. Read CLAUDE.md and the previous epic's retro doc (avoid duplication; check prior conventions held).
4. Present summary, then ask seven questions.

## Seven Questions

Ask one at a time, confirm after each answer.

1. **What did we ship?** → Final list of shipped stories with one-line outcomes.
2. **What went well?** → Approaches that paid off — patterns to keep, not change. Distinct from Q4 (codifying); this is reinforcement.
3. **What slowed us down?** → Blockers and root causes. For each blocker, ask "why didn't we catch this earlier?" at least twice (5-whys-lite).
4. **What patterns emerged?** → Approaches/structures/decisions worth codifying.
5. **Did last sprint's conventions hold?** → Read the previous retro's "CLAUDE.md Conventions Added" section. Audit one or two stories from this epic for each convention. Record violations as new blockers or pattern reinforcement.
6. **What should change?** → Process changes for next sprint (story creation, architecture, Dev Notes, testing).
7. **What goes into CLAUDE.md?** → Standing rules for all future sessions.

## Deferred Item Status Check

Read `docs/deferred-items.md`. Cross-ref against `docs/epics.md`:
- Scheduled/open: story in epics.md, not started or in progress
- Completed: story is done
- Removed: not in epics.md

**Hard rule:** If the retro reassigns a deferred item, edit `docs/deferred-items.md`'s `Scheduled As` column in the same turn. Narrating without editing is a failed retro.

Include summary in retro doc.

## PRD / Architecture Sync Check

Before writing the retro, diff `docs/prd.md` and `docs/architecture.md` against stories shipped. List any required updates. Perform them in the same turn.

## Metrics

Collect from `git log` and story files. Include in retro output:

```markdown
## Metrics
| Metric | Value | vs Last Epic |
|---|---|---|
| Stories shipped | N | +/- |
| Deferred items created | N | |
| Deferred items resolved | N | |
| Migrations added | N | |
| Test files added | N | |
| Story cycle time (median) | Nd | |
```

## Security Posture (security-sensitive epics only)

For epics touching auth, billing, or content moderation, include:
- What was reviewed
- Known accepted risks
- Deferred hardening items with story assignments

## Action Items

Output an `## Action Items` section with explicit checkboxes. **Perform each edit in the same turn** — do not just list them.

Example:
```markdown
## Action Items
- [x] Updated `docs/deferred-items.md` D-1 → Story X-Y
- [x] Promoted footgun: `vi.hoisted` pattern → CLAUDE.md
- [ ] (anything requiring user action outside this turn)
```

## Next Epic Readiness

End the retro with a `## Next Epic Readiness` section:
- PRD section exists for next epic?
- Architecture pre-reqs met?
- Blocking unknowns next epic inherits?
- `epic-{N+1}-context.md` initialized?
- Explicit **GO / HOLD** verdict.

## Output

1. Write to `docs/epics/epic-{epic_num}-retro-{date}.md`: summary, metrics, what went well, blockers, patterns, conventions-held audit, process changes, CLAUDE.md additions, security posture (if applicable), deferred items status, action items (checked off), next epic readiness.
2. Update CLAUDE.md with new/revised conventions (Q7). If >80 lines, prune: consolidate, remove examples, move verbose explanations to docs/.
3. Edit `docs/deferred-items.md` for any reassignments (mandatory — same turn).
4. Report: "Retrospective complete. CLAUDE.md updated. Next: `/create-story`."
