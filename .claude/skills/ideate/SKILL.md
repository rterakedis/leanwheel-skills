---
name: ideate
description: Recursive decision loop for ideation and planning — brainstorm a vague idea, pressure-test a formed one, or work down the open questions in the decision log until the way is clear. Use when the user has an idea (vague or formed), wants to brainstorm, stress-test, "forge", or "pressure-test" an idea, wants to plan a new product or feature area, or says "ideate" or "resume planning". Replaces /product-brief and /forge-idea.
---

# Ideate Skill

**Goal:** Turn fog into recorded decisions. The loop runs until nothing is left to decide
(hand off to `/spec`), the idea dies (log why), or the user parks the session (the log
persists — any later session resumes from it).

Planning progress lives in `docs/project/decisions.md`, owned by `decision-log`
(`skills/decision-log/SKILL.md`) — not in this conversation. Record as you go; a session
that ends mid-loop has lost nothing.

## Activation

1. Execute **LOAD** from `decision-log`.
2. If the Destination is empty (fresh effort): settle it first — what is this effort finding
   its way to, and what are the stakes (passion project / internal tool / investor pitch /
   public launch)? Stakes calibrate how hard to push for the whole effort; record both into
   the log's Destination. If `docs/project/brief.md` or other `docs/project/` inputs exist
   from earlier work, read them silently and seed the log from them (decisions the brief
   already makes → Decisions; its `[ASSUMPTION]` tags → Not yet specified) rather than
   re-asking.
3. Orient the user in two lines: the Destination, and the sharpest open question. Then loop.

## The loop

Repeat until an exit condition:

1. **Choose the question.** The user's, if they brought one; otherwise the open question
   whose answer unblocks the most others. One question per pass — new questions surfaced
   along the way go to **PARK**, not into this pass.
2. **Resolve it** by whichever fits:
   - **Elicit** — invoke `elicit` (`skills/elicit/SKILL.md`): Probe to settle, Pressure to
     stress-test, Diverge when the user has no formed answer. This is the default.
   - **Research** — when the answer hangs on external facts rather than the user's judgment,
     invoke `/research` scoped to the question; its Recommendation section is the input to a
     final Probe pass, not a substitute for the user deciding.
   - **Prototype** — when "how should it look/behave" is the question, make the cheapest
     concrete artifact that lets the user react (an outline, an HTML mock, a stub) and decide
     from the reaction. Artifacts go in `docs/project/.working/`, linked from the log entry.
3. **Record** via `decision-log` **RECORD** (or **RULE-OUT** when the answer is "not this
   effort"). Fold in anything the answer just made specifiable: sharpen parked lines you can
   now phrase, park what you newly can't.
4. **Check STATUS.** Empty frontier + filled Destination → the way is clear; exit.

## Exits

Every session ends in exactly one of these — all are valid outcomes:

- **Way clear** — nothing left to decide. Point at `/spec`: "Start a fresh session and run
  `/spec` to render the docs" (fresh session keeps the render off this conversation's
  context).
- **Killed** — the idea didn't survive pressure. Say so plainly (a successful use of the
  session), RECORD the core reason as a rejection, and offer a Diverge pass to re-enter with
  what was learned.
- **Parked** — the user stops mid-loop. Confirm the log reflects everything settled so far;
  next session resumes via this skill or `/next`.

## Boundaries

Resolve the question in front of you; new questions go to the log, not into this pass. Never
fabricate a differentiator or a moat to close a question — if "what makes this different" is
genuinely thin, record that plainly and let the user decide whether it kills the idea. Work
that surfaces here (a bug, a task, a chore) isn't a decision — route it to `deferred`
LOG-AND-SCHEDULE if a backlog exists, or park it as a question if it's really a decision in
disguise. When the idea touches information architecture (new or reorganized
navigation/screens), the JTBD → convergence-points → workflow mapping in `/spec`'s ux rule is
the shape the answer has to take — don't settle IA one affordance at a time here.
