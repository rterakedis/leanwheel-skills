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

### Pass 1 — Catch unlogged deferred items

Scan all story files for the epic just completed (`docs/epics/epic-{N}-*.md`) for any `[Defer]` checkbox entries (checked or unchecked). Compare against `docs/deferred-items.md`.

For each `[Defer]` item found in a story file that has **no matching D-ID** in `docs/deferred-items.md`: call **LOG-AND-SCHEDULE** from `skills/deferred/SKILL.md` immediately. Do not leave unlogged deferred items after the retro.

### Pass 2 — Ensure all logged items are scheduled into open work

Read `docs/deferred-items.md`. For every row, check the `Scheduled As` story against `docs/epics.md`:

- **Scheduled into an open (not-started or in-progress) story:** OK — no action.
- **Scheduled into a `Status: done` story or completed epic:** INVALID — that story is locked dev-complete. Reassign via **SLOT-INTO-BACKLOG** from `skills/deferred/SKILL.md` (targeting only stories with `Status: not started`). If no slot found, call **SCHEDULE** Step 2 to create a new remediation story. Update `Scheduled As` in `docs/deferred-items.md`.
- **Scheduled story not found in epics.md (removed/renamed):** Treat as unscheduled — reassign same as above.
- **Completed/resolved:** Note as resolved in retro doc, no action needed.

**Hard rule:** Every unresolved deferred item must point to an open, not-started story when the retro ends. Narrating without editing `docs/deferred-items.md` is a failed retro.

Include a summary table in the retro doc:
```markdown
| D-ID | Title | Was Scheduled As | Action Taken |
|------|-------|-----------------|--------------|
| D-1  | ...   | Story X.Y (done — reassigned to Z.W) | Slotted as AC |
| D-2  | ...   | Story X.Y (open) | No change |
```

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

## Security Sweep (mandatory — all epics)

Before writing the retro doc, run a scoped security review against all stories shipped in this epic. This is a blocking gate — no GO verdict until it completes.

**Scope determination:**
- Read story files for the epic. Collect all `Security Sensitivity:` values from Dev Notes.
- If any story touched auth, billing, payments, data-access, api, secrets, llm, or file-upload: run the matching categories from `skills/security-review/SKILL.md` checklists.
- If no `Security Sensitivity:` flags found: run Category: Secrets Management and Category: Data Exposure at minimum (always applicable).

**Steps:**
1. Run applicable checklist categories. Mark each item Pass / Fail (file:line) / N/A.
2. For any **critical or high** findings: call **LOG-AND-SCHEDULE** from `skills/deferred/SKILL.md` immediately. These must be scheduled before the GO verdict is issued.
3. For **medium/low** findings: include in retro doc under `## Security Findings` — user decides whether to schedule.
4. If zero findings across all applicable categories: write `Security sweep clean — no findings.`

Include in retro doc:
```markdown
## Security Findings
| Severity | Category | Finding | File:Line | Action |
|----------|----------|---------|-----------|--------|
| HIGH     | Auth     | ...     | ...       | Logged as D-N, Story X-Y |
| MEDIUM   | Headers  | ...     | ...       | Noted — user to schedule |
```

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
- All critical/high security findings logged and scheduled?
- Explicit **GO / HOLD** verdict. HOLD if any critical/high security finding is unscheduled.

## Output

1. Write to `docs/epics/epic-{epic_num}-retro-{date}.md`: summary, metrics, what went well, blockers, patterns, conventions-held audit, process changes, CLAUDE.md additions, security findings (mandatory), deferred items status, action items (checked off), next epic readiness.
2. Update CLAUDE.md with new/revised conventions (Q7). If >80 lines, prune: consolidate, remove examples, move verbose explanations to docs/.
3. Edit `docs/deferred-items.md` for any reassignments or newly logged items from the Deferred Item Status Check (mandatory — same turn). Every unresolved item must point to an open, not-started story.
4. Report: "Retrospective complete. CLAUDE.md updated. Next: `/create-story`."
