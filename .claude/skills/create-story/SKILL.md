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

**Story complexity (set this first — it scales the rest of this step):**
- **Stateful / multi-step** — has a state machine, a multi-step flow, concurrent actions, an async lifecycle, or non-trivial failure handling. Gets the full Behavior Contract + edge-case enumeration below and passes through the Clarification Gate.
- **Simple** — CRUD, config, copy, styling, or a pure refactor/migration with one obvious path. Behavior Contract is one line or omitted; the edge-case pass is a quick sanity check, not a full enumeration; the Clarification Gate is a no-op unless a real fork surfaces. Do not manufacture ceremony for simple stories.

**Behavior Contract & edge-case enumeration (stateful/multi-step stories):**
Before writing any ACs, draft the `### Behavior Contract` section (template) and enumerate edge cases explicitly. Do not lean on the passive "edge cases?" bullet above — produce a real list:
- **Flows:** each user/system flow as a step sequence — happy path plus every alternate path.
- **States & transitions:** the states involved, the valid transitions, and the **illegal** transitions that must be rejected.
- **Edge cases:** empty/boundary inputs; concurrent or duplicate actions; partial failure and retry/idempotency; offline/timeout; permission/auth edges; first-run vs returning.
- **Expected outcomes:** for each flow and edge case, the observable result (state change, message, side effect).
- **Invariants:** what must always hold regardless of path (e.g. "balance never negative", "exactly one active session").

Every enumerated edge case with a non-obvious outcome must become its own Given/When/Then AC — the enumeration is worthless if it stays in prose. Dev sessions test ACs, not Behavior Contract narrative.

**Cross-epic runtime dependency check (mandatory):**
Before writing, explicitly answer: does this story require a runtime artifact — database table, seed data row, API endpoint, migration, or service — that lives in a *different* epic and may not be complete yet?

If yes:
1. Note the dependency in Dev Notes under `### Prerequisites` with the source story ID (e.g. "Requires Story 13-1 migration `tenant_access_grants` to exist").
2. If the prerequisite epic/story is scheduled *after* this epic in `docs/epics.md`, flag it as a sequencing risk in the story summary shown to the user — they must decide to reorder, split, or accept the incomplete-until-X gap.
3. Never silently assume a later epic's output will be present.

**Design contract extraction (UI stories only):**
If the story adds or changes user-visible UI and `docs/ux/DESIGN.md` / `docs/ux/EXPERIENCE.md` exist:

1. Read DESIGN.md frontmatter and the EXPERIENCE.md sections for the surfaces this story touches — not the whole files.
2. Extract into Dev Notes under `### Design Contract` (use the template section):
   - The specific tokens the story's UI consumes (color/spacing/type/radius — values inline, not "see DESIGN.md")
   - The component specs involved (visual + behavioral rows for components being built or used)
   - Required states for each surface (empty / loading / error / offline, with the specced copy and placement)
   - Applicable platform checklist items (HIG items for Apple; guardrail items for web)
3. If `docs/ux/components-built.md` exists, list the existing components this story must **reuse** — instruct the dev session to never create a near-duplicate of an inventoried component.
4. If the UI the story needs has no coverage in EXPERIENCE.md (no surface, no states), flag it to the user before writing — that's a design gap, not a license to improvise.

This extraction is why dev sessions never read `docs/ux/` — the same economics as the epic context cache.

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

## Clarification Gate (before writing)

Do not write the story while any **material** flow is ambiguous — one whose resolution would change an AC or a task. This gate is the fix for thin ACs and downstream rework. From the Behavior Contract and edge-case enumeration, separate:

- **Stated assumptions** — ambiguities with one sensible default. Record the assumption inline (e.g. "assuming soft-delete") and proceed; the user corrects at review if wrong.
- **Material ambiguities** — genuine forks where you cannot pick a default without guessing at product intent (which state wins on conflict? is partial success allowed? what happens on re-entry?).

If any material ambiguity exists, **stop and ask the user** — list them concisely and wait for answers. Do not write speculative ACs around an unresolved fork. Trivial or simple stories with no material ambiguity skip straight to writing — do not invent questions to satisfy the gate.

In the autonomous flywheel this gate surfaces as a normal human-decision pause (Phase 1 blocks until create-story returns the story file).

## Write Story File

Use template. Rules:
- Tasks ordered by dependency, map to file + action
- Dev Notes: everything dev session needs (extract content, don't say "see docs")
- ACs: Given/When/Then format, independently testable; every material edge case from the Behavior Contract has its own AC
- References: cite specific files/sections

Output: `docs/epics/{epic}-{story}-{slug}.md`

## After Writing

Show story: what it implements, FRs satisfied, open questions. Request review.

After feedback:
1. Mark status `ready-for-dev`
2. Update cache with learnings
3. **Seed eval cases.** If `docs/evals/` exists, execute **BUILD** from `skills/evals/SKILL.md` for this story: derive `type: command` regression cases from the ACs and any Behavior Contract invariants (referencing the tests dev-story will write — `enabled: false` with a pending note until they land). This makes the story's intended behavior part of the cumulative regression net. Skip if `docs/evals/` is absent.

## GitHub Tracking

After user approval, execute from `skills/github-tracking/skill.md`:

1. **ENSURE-MILESTONE** — pass `epic_num` and epic title; store `milestone_title`
2. Check if issue already exists (created when epics.md was written):
   - `gh issue list --search "Story {epic}.{story}:" --json number,title --jq '.[0].number'`
   - If found: write the existing number back to frontmatter (`sed -i '' "s/^github_issue: 0$/github_issue: {N}/"`), then **TRANSITION** the issue from `backlog` → `ready-for-dev`. Skip CREATE-ISSUE.
   - If not found: **CREATE-ISSUE** — pass story path, `epic_num`, `story_num`, `story_title`, `milestone_title`, AC summary (uses default `initial_label: ready-for-dev`); writes `github_issue:` to frontmatter.

If GitHub unavailable, skip and note.
