---
name: spec
description: Render, update, or validate the planning documents — brief, PRD, UX (DESIGN.md + EXPERIENCE.md), and architecture — from the decision log. Use when the user wants to write, edit, or check any of these docs, says "spec", "render the docs", "create the PRD", "update the architecture", "write the brief", or "validate the UX spec". Replaces the create/update/validate flows of /prd, /ux, /architecture, and /product-brief's distill flow.
---

# Spec Skill

**Goal:** Turn recorded decisions into the planning documents downstream skills depend on.
Rendering is mostly mechanical — the thinking already happened in `/ideate` and lives in
`docs/project/decisions.md`. This skill drafts from the log and its templates, and elicits
only where a section has no backing decision.

**Targets** (from the argument, the user's words, or what's missing):

| Target | Output | Template / reference (this directory) |
|---|---|---|
| `brief` | `docs/project/brief.md` | `brief-template.md`, `brief-checklist.md` |
| `prd` | `docs/prd.md` | `prd-template.md`, `prd-checklist.md` |
| `ux` | `docs/ux/DESIGN.md` + `docs/ux/EXPERIENCE.md` | `design-template.md`, `experience-template.md`, `ux-checklist.md`, **`ux-presets.md`** (read before rendering ux) |
| `architecture` | `docs/architecture.md` | `architecture-template.md` |

## Activation

1. Execute **LOAD** from `decision-log` (`skills/decision-log/SKILL.md`). No log and no
   existing target doc → this is really an ideation task; route to `/ideate` and stop.
2. Detect intent per target: **Create** (doc absent), **Update** (doc exists + a change
   signal), or **Validate** (user asked for a check). Ask only if genuinely unclear.
3. Read the upstream docs the target inherits from — prd reads `brief.md`; ux reads
   `prd.md`; architecture reads `prd.md` (required — if missing, render prd first or stop)
   and `epics.md` if present — plus anything in `docs/project/` (research, ADRs, vendor
   notes). Read silently; no summaries back to the user.

## Create / Update

Draft the whole target from the log + template, then close the gaps:

- **Sections with backing decisions** render directly, citing the log rather than restating
  its reasoning.
- **Sections with no backing decision:** run one bounded `elicit` pass
  (`skills/elicit/SKILL.md`) for each — or, at the user's choice, tag the section
  `[OPEN: {question}]` and **PARK** the question in the log, so the doc ships with its gaps
  named instead of filled with guesses.
- Small inferences that aren't decision-shaped (a wording choice, an implied default) get
  `[ASSUMPTION: …]` tags in the doc as before; decision-shaped gaps go to the log, not the
  tag.
- Decisions settled during rendering are **RECORD**ed with `source: /spec` as they happen.
- Drop any template section that doesn't earn its place; add one the product genuinely needs.

For **Update**: read the doc and the change signal, surface conflicts with logged decisions
before applying (a contradiction means the log needs a superseding RECORD first), apply,
re-triage tags. If `docs/epics.md` shows in-progress or done epics and the change touches
scope or patterns, close with: "Run `/correct-course` — stories may need updating."

### Per-target rules

**brief** — 1–2 pages. Never fabricate a moat or differentiation claim: if "what makes this
different" is thin in the log, say so plainly in the doc. Real detail that doesn't fit
(rejected alternatives, sizing data, deep personas) goes to `docs/project/brief-addendum.md`.

**prd** — length scales with the stakes recorded in the log's Destination (hobby ~2 pages,
internal ~5, launch as long as needed). Features grouped; FRs nested with globally stable IDs
(FR-1, FR-2…). Capabilities only — no tech choices in the PRD body. Index assumptions in §9.

**ux** — *before an epic that adds or reorganizes navigation/screens*, map jobs-to-be-done →
convergence points (what must live together from the same starting view) → workflow, and only
then design UX to support it. Never accrete a sheet/button per story wherever it is locally
convenient — that is what produces disjointed flows. Then read `ux-presets.md` first: resolve the platform surface, apply the matching
preset(s), and treat its discovery areas as the section-by-section decision checklist. Two
peer contracts: DESIGN.md (visual identity) and EXPERIENCE.md (IA, behavior, states,
interactions, accessibility). Never duplicate PRD content — inherit by reference;
EXPERIENCE.md cross-references DESIGN.md tokens with `{path.to.token}` syntax. Before
`status: final`: every HIG checklist item resolved (✓ / – / [OPEN]), and walk every IA
surface classifying it mocked vs spine-only — for spine-only surfaces ask once whether any
need a visual reference, and log the answer either way.

**architecture** — cover: tech stack, data model, API/integration design, project structure,
key patterns and conventions (numbered — they are rules for dev sessions), testing strategy
(matrix: scope → tool → coverage). Before adding any new dependency, apply rungs ①–⑤ of the
simplicity ladder — does the standard library, a native platform feature, or an
already-chosen dependency cover it? Each dependency that stays carries a one-line
justification. If a pattern changed on an Update, `touch docs/architecture.md` and flag
`/correct-course` as above.

## Finalize (Create/Update)

1. Triage remaining `[ASSUMPTION]` tags — resolve anything that would change the doc's
   direction; note the rest.
2. Write the file(s); set `status: final` and `updated: {date}` where the template carries
   frontmatter.
3. Output: file path(s) + the next step — another `/spec` target if one is missing, else
   `/check-readiness` after `/epics`. Recommend a fresh session for the next phase.

## Validate

Read the target doc(s), run the matching checklist from this directory across all its
dimensions, and report: one-sentence verdict, then critical/high findings with locations and
fixes, medium/low as a tail count. Validation never edits.
