---
name: create-story
description: Create a comprehensive story file for a specific epic/story. Use when the user says "create story" or "create next story" or "create story {epic}-{story}".
---

# Create Story Skill

**Goal:** Story file complete enough that dev session needs only the story. All decisions, patterns, constraints in Dev Notes.

**Critical:** Thorough Dev Notes = dev tokens spent on coding, not re-discovery. Thin stories cause rework and regressions.

## Activation

### Step 1 — Identify target story
- If user specified epic/story (e.g., "1-2"), use it.
- Otherwise read `docs/epics.md`, find first story with no file in `docs/epics/`.
- Confirm: "Creating story {epic}-{story}: {title}?"

### Step 2 — Load documents via cache

Check cache validity:
```bash
[ -f docs/epics/epic-{epic_num}-context.md ] \
  && [ docs/epics/epic-{epic_num}-context.md -nt docs/prd.md ] \
  && [ docs/epics/epic-{epic_num}-context.md -nt docs/architecture.md ] \
  && echo "valid" || echo "stale"
```

**If valid:**
- Read `docs/epics/epic-{epic_num}-context.md` (replaces prd + architecture)
- Read relevant story entry in `docs/epics.md`
- Read completed `docs/epics/{epic_num}-*.md` for learnings
- Tell user: "Using epic context cache."

**If missing/stale:**
- Read `docs/prd.md`, `docs/architecture.md`, `docs/epics.md` fully
- Read completed `docs/epics/{epic_num}-*.md`
- Generate cache before writing story
- Tell user: "Generated epic-{epic_num} context cache."

**Command:** `/create-story refresh-cache` — force-regenerate cache regardless of timestamps.

### Step 3 — Analysis (internal, fills Dev Notes)

Extract from documents:
- Which FRs and testable consequences?
- Which UJs enabled?
- Applicable architecture conventions (Section 5)?
- Files/modules touched?
- Required libraries/frameworks/versions?
- Prior story constraints to maintain?
- Edge cases and error conditions?
- Required tests (from testing strategy)?

**Cross-epic runtime dependency check (mandatory):**
Before writing, explicitly answer: does this story require a runtime artifact — database table, seed data row, API endpoint, migration, or service — that lives in a *different* epic and may not be complete yet?

If yes:
1. Note the dependency in Dev Notes under `### Prerequisites` with the source story ID (e.g. "Requires Story 13-1 migration `tenant_access_grants` to exist").
2. If the prerequisite epic/story is scheduled *after* this epic in `docs/epics.md`, flag it as a sequencing risk in the story summary shown to the user — they must decide to reorder, split, or accept the incomplete-until-X gap.
3. Never silently assume a later epic's output will be present.

## Generate Cache

When cache is missing/stale, distill content into `docs/epics/epic-{epic_num}-context.md`:

- FRs and UJs for this epic only (not entire PRD)
- Architecture conventions relevant to this epic (not entire architecture doc)
- Dense, no prose padding; target 150–250 lines
- Append `## Prior Story Learnings` section (initially empty)

This is the source of truth for subsequent stories in the epic.

## Update Cache After Each Story

After user approves, append to cache's `## Prior Story Learnings`:

```markdown
### Story {epic}.{story}: {title}
- Files created/modified: {list}
- Patterns established: {new patterns}
- Conventions confirmed: {what proved correct}
- Gotchas discovered: {surprises or deviations}
```

## Write Story File

Use template. Rules:
- Tasks ordered by dependency, map to file + action
- Dev Notes: everything dev session needs (extract content, don't say "see docs")
- ACs: Given/When/Then format, independently testable
- References: cite specific files/sections

Output: `docs/epics/{epic}-{story}-{slug}.md`

## After Writing

Show story: what it implements, FRs satisfied, open questions. Request review.

After feedback:
1. Mark status `ready-for-dev`
2. Update cache with learnings

## GitHub Tracking

After user approval, execute from `skills/github-tracking/skill.md`:

1. **ENSURE-MILESTONE** — pass `epic_num` and epic title; store `milestone_title`
2. Check if issue already exists (created when epics.md was written):
   - `gh issue list --search "Story {epic}.{story}:" --json number,title --jq '.[0].number'`
   - If found: write the existing number back to frontmatter (`sed -i '' "s/^github_issue: 0$/github_issue: {N}/"`), then **TRANSITION** the issue from `backlog` → `ready-for-dev`. Skip CREATE-ISSUE.
   - If not found: **CREATE-ISSUE** — pass story path, `epic_num`, `story_num`, `story_title`, `milestone_title`, AC summary (uses default `initial_label: ready-for-dev`); writes `github_issue:` to frontmatter.

If GitHub unavailable, skip and note.
