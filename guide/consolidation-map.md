# Planning-Skill Consolidation Map

**Status: proposal.** Nothing in `.claude/skills/` has been changed yet. This document is the
target shape and the per-skill worklist for collapsing the planning/ideation surface from ~11
user-facing skills to 4–5, built around a recursive decision loop instead of a staged document
pipeline. Execution-side skills (epics → dev-story → review → flywheels → retro) are out of
scope and unchanged.

Inspiration credit: the decision-loop shape is adapted as an *idea* (never a file copy) from
Matt Pocock's [Wayfinder skill](https://github.com/mattpocock/skills/tree/main/skills/engineering/wayfinder)
— decisions as the unit of planning progress, a persistent "decisions so far" index, and a
deliberately incomplete "not yet specified" frontier. We do not adopt its issue-tracker
ceremony (map issues, child tickets, claiming, blocking edges); leanwheel keeps planning state
in `docs/`, which fits its token posture and solo/small-team audience.

---

## 1. Diagnosis (why consolidate)

Two structural problems, not a count problem:

1. **Duplicated elicitation engines.** product-brief (diverge/distill + technique table),
   forge-idea (adversarial grilling), prd (fast/coaching paths), ux (fast/coaching + discovery
   walk), and architecture (confirm-per-section walk) each re-implement "pull decisions out of
   the user one sharp question at a time." Five copies of one capability, each drifting
   independently.
2. **The process is the document.** "Write the PRD" *is* the planning activity, so planning
   progress is only legible as doc completeness, decisions are smeared across brief/prd/
   ux/architecture with no index, and anything that doesn't fit one session has nowhere to
   live except `[ASSUMPTION]` tags. There is no mechanism for a planning effort bigger than
   one session.

The fix inverts the second: **the unit of planning progress becomes the decision**, recorded in
a persistent log, and the spec documents become renderings of that log. The first is fixed by
factoring the elicitation discipline into one composable engine, the same pattern the execution
side already uses (`deferred`, `docs-sync`, `evals`, `github-tracking`).

---

## 2. Target architecture

### New persistent artifact: `docs/project/decisions.md` — the decision log

Single file, loaded at the start of every planning session, owned by the `decision-log`
composable. Sections:

```markdown
# Decision Log

## Destination
<one or two lines: what this planning effort is finding its way to>

## Decisions
- {date} — {decision, one line} — why: {reason}      <!-- append-only -->

## Rejected
- {date} — {what was considered and dropped} — why

## Not yet specified
<questions you can tell are coming but can't phrase sharply yet — the frontier>

## Out of scope
<consciously ruled out of this effort; never graduates back in>
```

Rules: a decision lives here once, never restated in a spec doc (specs cite it). "Not yet
specified" replaces most `[ASSUMPTION]` tag usage upstream of the PRD — an unresolved question
gets a home instead of a fabricated placeholder. The log is what makes planning resumable
across sessions: any session reloads it and continues the loop; nothing depends on
conversation memory.

### New composable engine: `grill`

The one elicitation engine, called by `/ideate` and `/spec` (and available to `correct-course`).
Its SKILL.md carries — exactly once, for the whole repo — the discipline currently duplicated
across five skills:

- One question at a time, in dependency order; never dump a list or a multiple-choice menu.
- Never let a fuzzy or overloaded term pass ("user" vs "buyer" vs "payer").
- Push concrete hypotheses to react to, not open "what do you think" prompts.
- Persona pressure on demand (competitor / buyer / domain expert / support engineer /
  finance reviewer, generated inline), attack/defend/switch-roles steering.
- No praise as social lubricant; state genuine strength plainly and move on.
- Stop condition: the caller's question is answered or the user parks it (→ Not yet specified).

Reference file `techniques.md` holds the divergent-thinking table (SCAMPER, Five Whys,
pre-mortem, …) and convergence techniques currently inlined in product-brief — loaded only
when a diverge pass actually runs.

### User-facing planning surface (after)

| Skill | Role |
|---|---|
| **`/ideate`** (new) | The recursive front door. Subsumes product-brief + forge-idea; calls `grill`, `research`, and `decision-log`. Loop: load log → surface the sharpest open question → resolve it (grill / research / cheap prototype) → record → re-check what fog cleared → repeat. Exits when nothing decidable remains (→ `/spec`), when the idea is **Killed** (log the reason, offer re-diverge), or when the user parks the session (log persists). Scales from one session on a small idea to many sessions on a deep one — same skill, no mode switch. |
| **`/spec`** (new) | Renders `docs/project/brief.md`, `docs/prd.md`, `docs/ux/DESIGN.md` + `EXPERIENCE.md`, and `docs/architecture.md` **from the decision log** plus their templates. Subsumes the write/update/validate flows of product-brief, prd, ux, and architecture. Where a template section has no backing decision: run one bounded `grill` pass for it, or (user's call) tag `[OPEN: …]` and add it to Not-yet-specified. Rendering is mostly mechanical — that's the point. |
| **`/check-readiness`** | Kept, lightly extended (see §3). |
| **`/correct-course`** | Kept; its triage phase becomes a scoped re-entry into the `/ideate` loop (see §3). |
| **`/next`** | Kept as router; table rows updated (see §3). |

Composables underneath: `grill` (new), `decision-log` (new), `research` (kept, now also
callable from `/ideate`), `deferred` (unchanged). `/discover` and `/dev-single-goal` are
unchanged entry points.

Planning surface goes from product-brief, forge-idea, prd, ux, architecture, research,
check-readiness, correct-course, next (9 user-facing) to ideate, spec, check-readiness,
correct-course, next (5), with the recursion coming from the decision loop being the same
loop at every altitude — new product, new feature area, mid-sprint change.

---

## 3. Per-skill worklist

### Retire into `/ideate` — `product-brief`, `forge-idea`

- **Keep as content** (moves into `/ideate` + `grill` reference files): the technique table
  and convergence menu (→ `grill/techniques.md`); the stance question (facilitator / creative
  partner / ideate-for-me); "never fabricate a moat" and the brief-length rules (→ `/spec`'s
  brief renderer); forge-idea's exit states (Hardened / Killed / Clearer become loop exits);
  the stakes-calibration question (asked once, recorded in the log's Destination).
- **Delete as structure:** the diverge→distill two-motion script, the six-step Distill flow,
  the Update/Validate flows (→ `/spec`), the `forged-idea-{slug}.md` handoff artifact — its
  Decisions/Rejected/Open shape *is* the decision log now, so the file and the
  product-brief↔forge-idea handoff choreography both disappear.
- **Routing text to carry over:** the "start a fresh session for the next phase" guidance
  survives, but as `/next`'s job, stated once there — not repeated at the end of each skill.

### Retire into `/spec` — write/update/validate flows of `prd`, `ux`, `architecture`

- **Keep as content, unchanged:** all three `template.md`/`checklist.md` files; ux's platform
  presets (web app / SSG / Apple) and the full Apple Platform section rules; the engagement-
  levers honesty framework; architecture's simplicity-ladder dependency rule and section list
  (stack / data model / API / structure / patterns / testing); prd's FR-ID and
  capabilities-not-tech rules. This is context and contract — never cruft.
- **Delete as structure:** each skill's brain-dump step, stakes question, fast-vs-coaching
  mode fork, and per-section confirm-then-wait choreography (architecture's "do not proceed
  until the user explicitly says to continue" is exactly the over-prescription §4 removes).
  `/spec` reads the log, drafts the doc, and grills only the genuinely open sections.
- **`[ASSUMPTION]` tags narrow, not vanish:** still used *inside a rendered doc* for small
  inferences, but anything decision-shaped goes to the log as `[OPEN]`/Not-yet-specified
  instead. The tag stops being the overflow bucket for unmade decisions.
- The three old skill names can remain as thin aliases for one release (`/prd` → "`/spec prd`
  does this now") or be cut immediately — maintainer's call; `/next` stops routing to them
  either way.

### `check-readiness` — keep, extend two checks

- Add to Check 5/10 territory: **no `[OPEN]` decision-log item may block an epic being
  gated** — an open question whose answer would change upcoming stories is a blocker (resolve
  via a scoped `/ideate` pass), one that wouldn't is a warning.
- Check 1's FR traceability now also spot-checks that load-bearing PRD sections cite log
  decisions rather than orphan `[ASSUMPTION]`s. Everything else unchanged.

### `correct-course` — keep, rewire Phase 1

- Phase 1 (triage the trigger) becomes: append the trigger to the decision log, run the
  `/ideate` loop scoped to it until the impact decisions are made, then proceed to the
  existing Phases 2–6 (classify / deferred pull-forward / execute / doc updates) unchanged.
  The deferred-items integration is untouched.

### `next` — keep, update the routing table

- Rows 3–7 re-route: no brief & no prd → `/ideate`; log exists with open Destination-level
  questions → `/ideate` (resume); log settled but docs missing/stale → `/spec {doc}`;
  detection gains one probe (`docs/project/decisions.md` existence + a grep for `## Not yet
  specified` content). Rows 8+ unchanged.

### Unchanged

`epics`, `create-story`, `dev-story`, `code-review`, both flywheels, `retrospective`,
`harvest-findings`, `epic-archive`, `deferred`, `docs-sync`, `evals`, `github-tracking`,
`discover` (optionally: teach it to seed a decision log from reverse-engineered choices —
later, not part of this consolidation), `doc-review`, `investigate`, `setup`,
`upgrade-project`, the audits and refreshers, `quick-dev`, `dev-single-goal`, `status`.

---

## 4. Authoring rules for the rewritten skills (5-series models)

Anthropic's guidance for prompting Claude 5-family models (Fable 5 / Opus 5 / Sonnet 5) —
from the model migration guide's behavioral-shift sections and the prompt-audit patterns —
changes how the new SKILL.md files should be written, not just what they contain. Apply these
while writing `/ideate`, `/spec`, and `grill`, and treat them as the bar for future edits to
any skill in this repo:

1. **State goals and constraints, not step choreography.** "Prompts and skills written for
   prior models are often too prescriptive for current ones and *reduce* output quality."
   Numbered steps survive only where order is genuinely fragile (file reads before writes,
   activation detection, git operations). The per-section "show → confirm → wait for explicit
   continue" walks are the canonical thing to delete — say *what a settled section looks
   like* and let the model run the conversation.
2. **Delete self-verification scaffolding.** 5-series models verify their own work unprompted;
   instructions like "double-check", "re-run the checklist before finalizing", or a mandated
   verification step cause over-verification with no quality gain. Checklists stay as
   *validate-mode reference files* the user can invoke; they stop being inline mandates inside
   create flows.
3. **No pressure language.** Current models follow the system prompt closely; `CRITICAL:`,
   `MUST`, `NEVER` walls over-trigger and make behavior rigid. State the one or two real
   constraints plainly, with the reason attached. Exception, per the trigger/behavior split:
   frontmatter `description` fields are *routing* text and may carry calibrated urgency,
   because skills under-trigger — keep tuning those against real invocation misses.
4. **Positive statements over prohibition lists.** Rewrite "never do X, don't Y, avoid Z" runs
   as the desired behavior with its reason. Keep prohibitions that encode a real constraint
   (dark-pattern rejection in the engagement levers, trademark rule) — those carry provenance.
5. **Every rule lives in exactly one skill.** The engine factoring is itself the application
   of this: elicitation discipline in `grill` only, session-hygiene routing in `/next` only,
   deferred mechanics in `deferred` only. Duplicated rules make the model reconcile wordings
   and drift over time. Cross-reference by invocation, never by restating.
6. **Scope discipline stated once.** 5-series models expand task scope and delegate readily;
   `/ideate` carries a single line — "resolve the question in front of you; new questions go
   to the log, not into this pass" — instead of per-flow guardrails.
7. **Context is never cruft.** The platform presets, HIG checklist, simplicity ladder, honesty
   checks, and templates are domain knowledge the model can't infer — they move intact. The
   cuts are process scaffolding only. Deliverable-length guidance (brief ≤ 2 pages, PRD scales
   with stakes) also stays: 5-series models write longer documents by default and respond well
   to explicit length calibration.
8. **Progressive disclosure.** SKILL.md files stay lean and single-pass (this repo's existing
   posture); technique tables, templates, and checklists live in reference files loaded only
   when their pass actually runs.

---

## 5. Suggested migration order

Each step is independently shippable and leaves the repo working:

1. **`decision-log` composable + `docs/project/decisions.md` format** — new skill, no callers
   changed yet. (Re-run the symlink sync after adding it.)
2. **`grill` composable** — extract from forge-idea/product-brief verbatim-then-tighten;
   forge-idea and product-brief updated to call it (shrinking, not yet retired).
3. **`/ideate`** — new skill wrapping the loop; product-brief and forge-idea become aliases,
   `/next` rows 3–4 re-route.
4. **`/spec`** — new skill; prd/ux/architecture create-update-validate flows collapse into it;
   templates/checklists/presets move under `spec/`; `/next` rows 5–7 re-route.
5. **check-readiness + correct-course extensions**, then delete the alias skills once `/next`
   and the docs stop mentioning them. Update `guide/comparison.md`, `guide/skills-reference.md`,
   and `guide/workflows.md` in the same pass.

Naming note: per the repo trademark rule, nothing ships named "BMAD"; likewise don't name
anything "wayfinder" — credit above is reference, the shipped names are `ideate`, `spec`,
`grill`, `decision-log`.
