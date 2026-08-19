---
name: create-story
description: Create a comprehensive story file for a specific epic/story. Use when the user says "create story" or "create next story" or "create story {epic}-{story}".
---

# Create Story Skill

**Goal:** Story file complete enough that dev session needs only the story. All decisions, patterns, constraints in Dev Notes — thin stories cause rework.

## Activation

### Step 1 — Identify target story
- If user specified epic/story (e.g., "1-2"), use it.
- Otherwise read `docs/epics.md`, find first story with no file in `docs/epics/`. Scan only epics with live `### Story` bodies — a collapsed epic (summary table) is closed; its rows already have files and are pointers, not specs.
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

**Collapsed epics (either branch):** the spec for a summary-table row lives in the linked `docs/epics/{N}-{M}-*.md` — read that file for prior-story detail, not `docs/epics.md`.

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
- **Stateful / multi-step** — state machine, multi-step flow, concurrent actions, async lifecycle, or non-trivial failure handling. Gets the full Behavior Contract + edge-case enumeration and passes through the Clarification Gate.
- **Migration-shaped** — one repeated mechanical change (rename across N call sites, type migration, dependency/API swap). Record `**Shape:** migration` as the first line of Dev Notes and order tasks as below. Orthogonal to the other two.
- **Simple** — CRUD, config, copy, styling, or a refactor with one obvious path. Behavior Contract is one line or omitted; edge-case pass is a sanity check; Clarification Gate is a no-op unless a real fork surfaces. Don't manufacture ceremony.

**Task ordering for migration-shaped stories:** the durable deliverable is the *invariant test*, not the N edits (DD-11). **Task 1 is "write the invariant test; run it; confirm it fails, enumerating every violation"**, the sweep follows, and the final task re-proves the test by reverting exactly one instance and confirming a failure that names it. Give the test its own AC.

**Behavior Contract & edge-case enumeration (stateful/multi-step stories):**
Before writing any ACs, draft the `### Behavior Contract` section (template) with a real list:
- **Flows:** each user/system flow as a step sequence — happy path plus every alternate path.
- **States & transitions:** states, valid transitions, and the illegal transitions to reject.
- **Edge cases:** empty/boundary inputs; concurrent or duplicate actions; partial failure and retry/idempotency; offline/timeout; permission/auth edges; first-run vs returning.
- **Expected outcomes:** for each flow and edge case, the observable result (state change, message, side effect).
- **Invariants:** what holds regardless of path (e.g. "balance never negative", "exactly one active session"). Each needs evidence at dev time (DD-14).

Every enumerated edge case with a non-obvious outcome becomes its own Given/When/Then AC — dev sessions test ACs, not narrative.

**Simplicity lens (scaled by complexity):** ask *does each AC and Dev Notes section need to exist?* — prune speculative ACs and scaffolding. For any new dependency or abstraction, apply ladder rungs ①–⑤ (`## Simplicity & Anti-Over-Engineering`, DD-53): existing helper, standard library, or native platform feature before new machinery.

**Manual steps (Dev Notes structure):**
Any step the user performs in a GUI or console — not the terminal — goes in a `### Manual Steps` subsection of Dev Notes as numbered steps (test-plan setup too). Verify any GUI path against the installed toolchain version — a wrong menu path is a hard stop for a new operator.

**Cross-epic runtime dependency check:**
Before writing, answer: does this story require a runtime artifact (table, seed row, endpoint, migration, service) that lives in a *different* epic and may not be complete yet?

If yes:
1. Note the dependency in Dev Notes under `### Prerequisites` with the source story ID (e.g. "Requires Story 13-1 migration `tenant_access_grants` to exist").
2. If the prerequisite is scheduled *after* this epic in `docs/epics.md`, flag it as a sequencing risk in the story summary — the user decides to reorder, split, or accept the gap.
3. Never silently assume a later epic's output will be present.

**Testability contract (UI stories on Apple projects — runs whether or not `docs/ux/` exists):**
If the story adds or changes user-visible UI and `docs/setup/swift/testability.md` exists, name these in the story's `### Design Contract` before dev starts, so dev implements a list and `/design-verify`, flows, and `/e2e-tests` can address the UI by name (DD-52):

1. **Accessibility identifiers** — one per interactive element and per dynamic list row on the story's surfaces, as `{feature}-{element}-{role}` kebab-case (e.g. `invoice-save-button`, `invoice-row-\(item.id)`). Derive `{feature}` from the story's feature area so names stay collision-free across epics.
2. **Deep-link route** — if the story adds a screen, name the route that reaches it (`{scheme}://invoices`). A screen with no route is unreachable by screenshot verification and future flows.
3. **Seed scenario** — which existing `SeedScenario` renders this story's states, or which one needs extending. Never "tap to set up state."

If the project has no `docs/ux/`, emit a Design Contract containing only these — the section is not gated on `docs/ux/` existing.

**Design contract extraction (UI stories with `docs/ux/`):**
If the story adds or changes user-visible UI and `docs/ux/DESIGN.md` / `docs/ux/EXPERIENCE.md` exist, add to the same section:

1. Read DESIGN.md frontmatter and the EXPERIENCE.md sections for the surfaces this story touches — not the whole files.
2. Extract into Dev Notes under `### Design Contract` (use the template section):
   - The specific tokens the story's UI consumes (color/spacing/type/radius — values inline, not "see DESIGN.md")
   - The component specs involved (visual + behavioral rows for components being built or used)
   - Required states for each surface (empty / loading / error / offline, with the specced copy and placement)
   - Applicable platform checklist items (HIG items for Apple; guardrail items for web)
3. If `docs/ux/components-built.md` exists, list the existing components this story reuses — the dev session does not create a near-duplicate of an inventoried component.
4. If the UI the story needs has no coverage in EXPERIENCE.md (no surface, no states), flag it to the user before writing — a design gap, not a license to improvise.

Dev sessions read the Design Contract, never `docs/ux/` (DD-52).

## Generate Cache

When cache is missing/stale, distill content into `docs/epics/epic-{epic_num}-context.md`:

- FRs and UJs for this epic only (not entire PRD)
- Architecture conventions relevant to this epic (not entire architecture doc)
- Dense, no prose padding; target 150–250 lines
- Append `## Prior Story Learnings` section (initially empty)

This is the source of truth for subsequent stories in the epic.

The cache is a **deliverable** of this run with the same standing as the story file (DD-23). Verify the file exists before reporting the story complete.

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

Do not write the story while any **material** flow is ambiguous — one whose resolution would change an AC or a task. From the Behavior Contract and edge-case enumeration, separate:

- **Stated assumptions** — ambiguities with one sensible default. Record the assumption inline (e.g. "assuming soft-delete") and proceed; the user corrects at review if wrong.
- **Material ambiguities** — genuine forks where you cannot pick a default without guessing at product intent (which state wins on conflict? is partial success allowed? what happens on re-entry?). A proposed new dependency or single-caller abstraction is a material item — confirm it earns its place.

If any material ambiguity exists, **stop and ask the user** — list them concisely and wait for answers. Simple stories with no material ambiguity skip straight to writing; do not invent questions to satisfy the gate.

In the autonomous flywheel this gate surfaces as a normal human-decision pause (Phase 1 blocks until create-story returns the story file).

## Write Story File

Use template. Rules:
- Tasks ordered by dependency, map to file + action
- Dev Notes: everything dev session needs (extract content, don't say "see docs")
- ACs: Given/When/Then format, independently testable; every material edge case from the Behavior Contract has its own AC
- References: cite specific files/sections

- **Done stories are immutable** — never reopen a `status: done` story; author a new story `{N}.{last+1}` instead (per harvest-findings, DD-33)

Output: `docs/epics/{epic}-{story}-{slug}.md`

## After Writing

Show story: what it implements, FRs satisfied, open questions. Request review.

After feedback:
1. Set `status: ready-for-dev` in the **YAML frontmatter** — the machine-readable source of truth; a body `**Status:**` line is forbidden (DD-51)
2. Update cache with learnings
3. **Seed eval cases.** If `docs/evals/` exists, execute **BUILD** from `skills/evals/SKILL.md` for this story: derive `type: command` regression cases from the ACs and any Behavior Contract invariants (referencing the tests dev-story will write — `enabled: false` with a pending note until they land). Skip if `docs/evals/` is absent.

## GitHub Tracking

After user approval, execute from `skills/github-tracking/SKILL.md`:

1. **ENSURE-MILESTONE** — pass `epic_num` and epic title; store `milestone_title`
2. Check if issue already exists (created when epics.md was written):
   - `gh issue list --search "Story {epic}.{story}:" --json number,title --jq '.[0].number'`
   - If found: write the existing number back to frontmatter (`sed -i '' "s/^github_issue: 0$/github_issue: {N}/"`), then **TRANSITION** the issue from `backlog` → `ready-for-dev`. Skip CREATE-ISSUE.
   - If not found: **CREATE-ISSUE** — pass story path, `epic_num`, `story_num`, `story_title`, `milestone_title`, AC summary (uses default `initial_label: ready-for-dev`); writes `github_issue:` to frontmatter.

If GitHub unavailable, skip and note.
