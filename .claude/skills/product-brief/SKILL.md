---
name: product-brief
description: Help the user arrive at a formed product idea (brainstorm if needed) and distill it into docs/project/brief.md — the upstream input /prd reads. Use when the user has a vague idea, wants to brainstorm, or wants to write a product brief before starting a PRD.
---

# Product Brief Skill

**Goal:** Get the user from "I don't know what I'm building yet" (or a half-formed idea) to a tight, written `docs/project/brief.md` that `/prd` can read as its starting input. One skill, two motions — **diverge** (generate options if none exist yet) then **distill** (write the chosen one down).

**Your role:** Facilitator first, writer second. In the diverge motion you pull ideas out of the user — never supply them unless asked. In the distill motion you write tightly and tag every inference.

## Activation

1. Check `docs/project/brief.md` → detect **Create**, **Update**, or **Validate**. Ask if unclear.
2. If invoked with a `docs/project/forged-idea-{slug}.md` (returning from `/forge-idea` with a Hardened result), treat as **Update**: read it as the change signal — see Update Flow.
3. For **Create**: check `docs/project/` for any other existing inputs (notes, research). If found, read silently (no summary).
4. Ask: **"Do you already have a formed idea, or do you want help generating one?"** → routes to Diverge or straight to Distill.

## Diverge Flow — Brainstorm (only when the user has no formed idea yet)

### Step 1 — Frame it
One compound question: **what** are we brainstorming, and **why** (the goal). The goal shapes which techniques fit — "find a wedge into a crowded market" calls for different techniques than "expand a single feature idea."

### Step 2 — Stance
Ask once, default to Facilitator if unanswered:
- **Facilitator** — you never supply ideas, pure forcing function, push past the obvious.
- **Creative Partner** — you trade ideas too, "yes-and" the user's.
- **Ideate-for-me** — you generate autonomously; user reacts and steers.

### Step 3 — Generate
Pick 3–4 techniques fitting the stated goal from this list (don't menu them to the user — choose and announce):

| Technique | Best for |
|---|---|
| SCAMPER (Substitute/Combine/Adapt/Modify/Put-to-other-use/Eliminate/Reverse) | Evolving an existing concept |
| Five Whys | Finding the real underlying need |
| Reverse Brainstorming | "How would this fail?" — surfaces risks as ideas |
| What-If Scenarios | Constraint removal/addition (no budget, 10x users, zero internet) |
| Forced Relationships | Combine with an unrelated domain/object |
| Six Thinking Hats | Structured multi-perspective pass (facts/emotion/risk/benefit/creative/process) |
| First Principles | Strip to fundamentals, rebuild from scratch |
| Worst Possible Idea | Generate bad ideas, then invert each |
| Analogical Thinking | "How does another industry solve this?" |
| Role Storming | Brainstorm in-character as a competitor, skeptic, or specific user type |
| Assumption Reversal | List assumptions about the problem, flip each one |
| Pre-mortem | "It's a year from now and this failed — why?" |

Run each technique to a natural stopping point, not a fixed count. Discipline: one prompt per message during generation (no multiple-choice menus), shift technique when ideas slow down, resist concluding early — push past the first 5–10 obvious ideas before judging anything.

### Step 4 — Converge
Offer convergence once generation has slowed or the user signals readiness. Pick **one** fitting technique, don't menu it:
- **Affinity Clustering** — group related ideas, name the clusters.
- **Impact/Effort Matrix** — plot for quick wins vs. big bets.
- **Forced Ranking / Dot Vote** — narrow a long list fast.
- **NUF Test** — New / Useful / Feasible, score each survivor.

Land on one (or a small connected set) of ideas the user wants to take forward. This becomes the input to Distill.

## Distill Flow — Write the Brief

### Step 1 — Brain dump
If arriving from Diverge, the converged idea *is* the brain dump — confirm it back to the user in one paragraph. Otherwise: ask the user to describe the product. One prompt.

### Step 2 — Stakes calibration
One question: passion project / internal tool / investor pitch / public launch? Calibrates how hard to push on rigor and differentiation claims.

### Step 3 — Working mode (pick one)

**Fast path** — Batch remaining gaps into 1–2 consolidated questions, draft the full brief with `[ASSUMPTION: …]` tags where inferred. User reviews and iterates. Default if unspecified.

**Coaching path** — Walk through the brief's sections together, one "tell me about X" at a time; never name answers or build multiple-choice lists.

### Step 4 — Write
Apply `template.md`. Rules:
- 1–2 pages. Drop any section that doesn't earn its place; add one the product genuinely needs.
- Tag every inference: `[ASSUMPTION: …]`.
- **Never fabricate a moat or differentiation claim** — if "what makes this different" is genuinely thin, say so plainly rather than inventing one.
- Detail that's real but doesn't belong in a 1–2 page brief (rejected alternatives and why, sizing data, deep personas) goes to `docs/project/brief-addendum.md`, not into the brief itself.

### Step 5 — Finalize
1. Triage `[ASSUMPTION]` tags. Resolve anything that would change the brief's direction; note the rest.
2. Write `docs/project/brief.md` (and `brief-addendum.md` if overflow content exists).
3. **Offer the pressure-test:** "Want to stress-test this before locking it in? (`/forge-idea`)" If yes, hand the brief as context to `/forge-idea`.

### Step 6 — Next step
- If the user just returned from a **Hardened** `/forge-idea` session with revisions: apply them (see Update Flow), re-finalize, then proceed to this step.
- If `/forge-idea` came back **Killed**: don't write the brief — tell the user plainly, offer to re-enter Diverge with what was learned.
- Otherwise (declined the pressure-test, or it came back **Clearer** with no changes needed): the brief is done. Output the file path, then:
  > "Brief is final. Start a **new session** and run `/ux` next if this ships a user interface, or `/prd` if it doesn't."

A new session is recommended (not just "run /ux now") so the next phase starts with a clean context window rather than carrying the full brainstorm/brief conversation forward.

## Update Flow

1. Read `docs/project/brief.md`.
2. Read the change signal — either a `docs/project/forged-idea-{slug}.md` handoff from `/forge-idea`, or a direct user request.
3. Surface conflicts with the existing brief before applying.
4. Apply. Re-triage `[ASSUMPTION]` tags.
5. Save. Return to Distill Flow Step 6 for the next-step output.

## Validate Flow

1. Read `docs/project/brief.md`.
2. Run `checklist.md`.
3. Report: one-sentence verdict, then critical/high findings with locations and fixes. Medium/low as a tail count.
