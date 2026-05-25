---
name: prd
description: Create, update, or validate a PRD. Use when the user wants to produce, edit, or check a PRD.
---

# PRD Skill

**Goal:** Produce a high-quality PRD scoped to the level of rigor the project actually needs.

**Your role:** Facilitator who pulls the user's vision out — not a content generator who fills sections for the sake of completeness.

## Activation

1. Detect intent: **Create**, **Update**, or **Validate**. Ask if unclear.
2. For **Update/Validate**, read `docs/prd.md`.
3. For **Create**, check `docs/project/` for upstream inputs. If found, read them silently (no summary). If absent, proceed.

## Create Flow

### Step 1 — Brain dump
Ask user to describe the product. One prompt.

### Step 2 — Stakes calibration
One question: hobby/internal/launch?

### Step 3 — Working mode (pick one)

**Fast path** — You batch remaining gaps into 1–2 consolidated questions, then draft the full PRD with `[ASSUMPTION: …]` tags where you inferred. User reviews and iterates. Best when the user gave you a lot upfront.

**Coaching path** — Walk through sections together: Vision → Target User → Glossary → Features → MVP Scope → Success Metrics. Ask open-ended "tell me about X" questions; never name answers or build multiple-choice lists. User can choose entry point: **Vision + Features** (thinks in capabilities) or **Journey-led** (thinks in user flows).

Offer the choice; default to Fast path if the user doesn't specify.

### Step 4 — Write
Apply the template in `template.md`. Rules:
- Length scales with stakes: hobby ~2 pages, internal ~5, launch as long as needed.
- Features grouped; FRs nested with globally stable IDs (FR-1, FR-2...).
- Capabilities only — no tech choices in the PRD body.
- Tag every inference: `[ASSUMPTION: …]`. Index all assumptions in §9.
- Drop any section that doesn't earn its place. Add any section the product genuinely needs that the template doesn't cover.

### Step 5 — Finalize
1. Triage `[ASSUMPTION]` tags. Resolve phase-blockers; note others with owner.
2. Run checklist from `checklist.md`. Surface critical/high findings only.
3. Write to `docs/prd.md`.
4. Output: file path + next step.

## Update Flow
1. Read `docs/prd.md` and the change signal.
2. If from `docs/project/`, read that file too.
3. Surface conflicts before applying.
4. Apply. Re-triage `[ASSUMPTION]` tags.
5. Save to `docs/prd.md`.
6. Scan `docs/epics/` for `in-progress`/`done` status. If found, output: "Run `/correct-course` — stories may need updating. Affected: {list}."

## Validate Flow
1. Read `docs/prd.md`.
2. Run the checklist in `checklist.md` across all seven dimensions.
3. Report: one-sentence verdict, then critical/high findings with locations and suggested fixes. Medium/low summarized as a tail count.
