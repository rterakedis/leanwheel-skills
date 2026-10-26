[← Back to README](../README.md)

## What Was Cut vs Original BMAD

> **Historical note.** The two tables below record the port decisions against the upstream
> BMAD that existed when this repo was created (the v4/v5 YAML/XML-workflow era). Upstream
> has since been rebuilt — see [Upstream state as of October 2026](#upstream-state-as-of-october-2026)
> for what's true now, including items upstream has independently cut or converged on.

| Cut | Why |
|-----|-----|
| Activation ceremony (config.yaml, resolve_customization.py, 6-step boot) | Ran on every skill invocation even with zero customizations — pure overhead |
| Three-tier TOML customization surface | Replaced by plain-English rules in `CLAUDE.md` |
| Sprint-status.yaml | Replaced by GitHub issue labels — same visibility, no extra file |
| BMAD agent personas (bmad-agent-pm, bmad-agent-architect, etc.) | Extra persona tokens on every skill invocation — not needed for solo use |
| Step-file JIT architecture (8 files for architecture alone) | Collapsed to single inline workflow |
| 1,512-line retrospective | Replaced with 7 focused questions (5 upstream + 2 local additions) |
| PRD decision log + addendum | Captured inline in story Dev Notes instead. (A *project-wide* decision ledger, `docs/project/decisions.md`, later arrived via the decision-loop consolidation — see the added-capabilities table — serving planning across all docs rather than per-PRD bookkeeping) |
| HTML validation reports | Overkill for personal workflow |
| UX/design agent persona (Sally) | Agent persona tokens not needed; UX workflow ported as `/ux` skill with Apple HIG + SwiftUI + responsive web support |
| Checkpoint preview | Covered by the independent code-review that runs after every story |
| Advanced-elicitation menu (CSV method registry, interactive 1-5/r/a/x loop) | The one high-value method for this workflow — pre-mortem — is folded into `/check-readiness` as Check 10; the menu/registry infrastructure is ceremony |
| PRFAQ / working-backwards challenge | `/ideate` (originally `/forge-idea`) already covers the adversarial idea-validation function; PRFAQ is a format, not a capability |

## What Leanwheel Added That Original BMAD Didn't Have

| Added | Why |
|-------|-----|
| Epic context cache (`docs/epics/epic-N-context.md`) | Eliminates re-reading PRD + architecture on every story after the first |
| Inline code-review at end of dev-story | Eliminates session startup cost; review runs while context is live |
| Security review skill (OWASP + LLM-specific) | Original BMAD had no security audit step |
| Deferred items auto-scheduling (`docs/deferred-items.md`) | Deferred findings in original BMAD went nowhere; now auto-scheduled as stories |
| Session hygiene guidance | Prevents silent context accumulation across planning phases |
| `/check-readiness` planning gate | Validates FR coverage, AC quality, and architecture alignment before coding starts |
| `/deferred` direct view command | Single-file log replaces error-prone project-wide grep |
| Subagent delegation via `/story-flywheel` | Each phase (create/dev/review) runs in an isolated context — heavy reads never accumulate in the main thread; model routing (Opus for Swift dev, Sonnet elsewhere) is automatic |
| Deterministic guardrail hooks (`.claude/hooks/`) | Secret prevention, off-token color warnings, and telemetry move from "the model remembers" to "the harness enforces" — zero model tokens |
| Observability ledger (`docs/metrics/flywheel-ledger.jsonl`) | Per-story quality and cost data queryable with `jq` — tracks build results, eval pass rates, and finding counts across the project lifetime |
| Cumulative eval regression net (`docs/evals/`) | AC-derived eval cases accumulate across stories; a failing eval on a later story surfaces a regression before review, exactly like a red build |
| `/upgrade-project` | Keeps existing projects in sync with new skills/hooks/stubs without manual file hunting or overwriting local edits |
| `/epic-flywheel` | Drives a whole epic end-to-end semi-autonomously — granular commits per story phase, within-epic auto-advance on green, Epic Boundary Gate, deferred re-homing, and a physical-device-backlog that persists across epics |
| `scripts/commit-push.sh` | Zero-reasoning commit helper scaffolded by `/setup` into every project — one call to stage, commit (with Co-Authored-By), and push; eliminates the multi-command git dance inside AI sessions |
| `/product-brief`, `/forge-idea`, `/research` | A pre-PRD idea-formation layer, reintroduced after initially being cut as ceremony-only (see prior revision of this table). `/prd`'s "describe the product, one prompt" Step 1 was a real gap when the user doesn't have a formed idea yet — `/product-brief` diverges (brainstorm) then distills (writes `docs/project/brief.md`) in one skill; `/forge-idea` adversarially pressure-tests it; `/research` grounds decisions in cited web research. All three are lean single-pass ports, not direct copies — upstream's three separate research-variant skills collapse into one with a type selector, upstream's CSV-served 100+-technique brainstorming catalog collapses into a small inline list. The brief/forge flows have since been folded into the decision-loop architecture (see below) — `/product-brief` and `/forge-idea` are now thin aliases; `/research` remains standalone |
| `/e2e-tests` | Lean port of upstream `bmad-qa-generate-e2e-tests`, reintroduced after initially being cut (story-level testing covers new work, but brownfield code, pre-evals features, and the manual epic test plan had no automation path). Retro-fits API/E2E tests onto existing features and registers every suite as zero-token `command` eval cases — one authoring session buys a permanent regression net, and converted test-plan scenarios permanently shrink the manual test pass |
| `/doc-review` | Merges upstream's three editorial skills (structure, prose, adversarial-general) into one three-pass skill — same merge move as `/research`. Closes the asymmetry where code gets adversarial review but planning docs never get reviewed as *writing*; since the model re-reads those docs every downstream session, cutting bloat is a token saving that recurs for the life of the project |
| `/dev-single-goal` | Doc-free entry lane: drop into *any* folder (no `docs/` tree, no leanwheel scaffolding) and drive one stated goal through grilled requirements (Behavior Contract + Clarification Gate), an approved verifiable plan, implementation, and a verify-by-running Build & Test Gate. Composes the pieces the project lanes already field-tested; the spec self-ignores in `.leanwheel/goals/` so the host repo stays clean, and escalation to `/discover`//`setup` is offered only on signal |
| Pre-mortem gate (Check 10 in `/check-readiness`) | Upstream ships pre-mortem as one menu option in `bmad-advanced-elicitation`; here it runs automatically inside the readiness gate, where the three planning docs are already in context — plan-level red-teaming to complement `/ideate`'s idea-level pressure test |
| Decision-loop planning architecture (`/ideate`, `/spec`, `elicit`, `decision-log`) | Replaces the per-document planning skills (`/product-brief`, `/forge-idea`, `/prd`, `/ux`, `/architecture` — kept as thin aliases for one release): the unit of planning progress becomes the *decision*, recorded in `docs/project/decisions.md`, and the spec docs become renderings of that log via `/spec`; one composable questioning engine (`elicit`) replaces five inlined copies of the same elicitation discipline. Not from BMAD — the decision-loop shape is an idea-port (never a file copy) of Matt Pocock's [Wayfinder skill](https://github.com/mattpocock/skills/tree/main/skills/engineering/wayfinder): decisions as the unit of progress, a persistent decisions index, a deliberate "not yet specified" frontier. Its issue-tracker ceremony (map issues, child tickets, claiming) is not adopted — planning state stays in `docs/`. Full design record: [consolidation-map.md](consolidation-map.md) |

---

## Upstream state as of October 2026

Upstream shipped **v6.0.0 stable (~March 2026)** and replaced its entire legacy
architecture with a skills-based one, then kept moving fast. As of October 2026 it runs on
**two lines**: **v6.12** (September 2026) is the frozen stable release, maintained for bug
fixes on the `V6.12` branch and installed by the legacy npm installer; `main` is a **v7
preview alpha** (release was due 16 October 2026 and has slipped) installed via
`npx skills add` or a plugin marketplace. Several claims elsewhere in this doc's history —
and several rows in the tables above — describe an upstream that no longer exists. Current
facts, verified against the upstream repo, changelog, and `bmad-loop` releases
(October 2026):

### What upstream cut too (convergence on lean)

- **The activation ceremony is gone upstream.** Config now resolves through layered TOML
  read by a renderer script, not a 6-step boot.
- **The SM → new chat → DEV → new chat → QA cycle is gone.** There is no upstream
  create-story or dev-story anymore. v6.11 renamed Quick Dev to `bmad-build` — "the one
  official way BMad implements code" — with `bmad-build-auto` as its unattended variant.
  v6.12 made Build decide how much ceremony a change needs *after* investigating it: simple
  changes get a two-section spec and finish in one session.
- **Catalog consolidation mirrors leanwheel's merge moves.** Three review skills plus two
  editorial skills became lenses on one `bmad-review` (`adversarial`, `edge-case-hunter`,
  `verification-gap`, `structure`, `prose`); three research skills became
  `bmad-deep-recon`; `check-implementation-readiness` folded into sprint planning. These are
  the same merges leanwheel made first with `/doc-review`, `/research`, and
  `/check-readiness`.
- **Upstream's own `AGENTS.md` now states leanwheel's DD-01/DD-02 philosophy** nearly
  verbatim: prompt length is paid on every run while a corner case is paid only when it
  occurs; prefer deleting an instruction to hedging it; automated tests assert outcomes of
  deterministic code, never LLM output or static prompt text.
- **Uppercase `SKILL.md` is the upstream convention** (since v6.1). Web bundles, Gemini
  Gems, Custom GPTs, HTML review reports, and translated docs are all removed.
- **Test Architect (TEA) moved out** to an external enterprise module (v6.9);
  `bmad-qa-generate-e2e-tests` remains in the shipped set.

### What upstream added that parallels leanwheel

- **`bmad-loop` (separate repo, v0.13.x by October 2026)** is upstream's epic flywheel: an
  unattended pick-story → implement → verify → gated adversarial review → re-verify →
  commit loop with deferred-work sweeps at epic boundaries. Its architecture is the
  *inverse* of `/epic-flywheel`: a deterministic pure-Python orchestrator (no LLM in the
  control loop) that spawns a fresh coding-agent CLI session per step in tmux, driven by
  a `policy.toml` (retry budgets, oscillation detection), with resumable journaled run
  state and git-worktree isolation. Since August it gained: a headless **auto
  retrospective at each epic boundary** whose open action items are filed into the
  deferred-work ledger; **environment probes** that run before verify and before each
  session, so an infrastructure fault pauses the run *without charging the story an
  attempt* (a verify command can also return a reserved exit code meaning "environment,
  not code"); `resolve --reverify` to re-run verification on kept work with no new dev
  session; and plugin hooks that observe structured verification results. Leanwheel's
  orchestrator is an in-session LLM thread holding short structured subagent reports,
  which lets it make cheap mid-loop judgment calls (auto-advance on clean stories,
  decision surfacing, the boundary test-plan subtract) that a Python loop cannot.
- **Real programmatic subagents.** Since v6.2–6.4, upstream's code review spawns parallel
  review-layer subagents with a deliberate asymmetry — subagents report, the
  orchestrating session traces consequences and triages. v6.11–6.12 added a
  **verification-gap layer** ("if this behavior broke, would any test fail?" — reports
  untested behavior changes, not bugs; tightened in October so a gap exists only when a
  concrete regression test in the repo's own suite could catch it, plus a
  *stale-verification* shape: a test that asserts the exact wrong outcome the change
  fixed), an **Intent Alignment Auditor** fed the verbatim invocation intent, **triage
  that logs a verdict and evidence for every finding** so nothing is dropped silently,
  and a **scored follow-up trigger** (any high, or `3 × medium + 1 × low ≥ 5`) instead of
  a judgment call. The adversarial lens dropped its persona for a method after A/B runs
  showed the "cynical reviewer" framing changed nothing while a ten-finding floor did.
  No evidence upstream ships `.claude/agents/*.md` agent definition files; leanwheel's
  four pinned `lw-*` agents with report contracts and model/effort frontmatter remain a
  structural difference.
- **Codebase research with citations.** `bmad-deep-recon` (v7) researches the repository
  itself: it turns the ask into factual questions, answers them from code and git history,
  cites a line or commit for every claim, recommends nothing, and offers decisions found
  in history as ADRs the user approves. `bmad-retrospective` likewise proposes ADRs from
  the decisions frozen in an epic's plans. Closest leanwheel analogues: `/investigate`,
  `/discover`, and the decision log.
- **Skill-level evals.** `bmad-eval` (v7, from the Builder module) evals the *skills
  themselves* — baseline vs. bare model, stripped-variant vs. full, rubric quality, and
  trigger accuracy of the description — each case in a clean-room harness. Interesting for
  this repo's own `evals/` dir, but it brings `uv`, harness config recorded via
  `bmad-customize`, and a 156 KB skill.
- **Shared concepts, direction of influence unknown.** forge-idea, a DESIGN.md +
  EXPERIENCE.md dual UX spine, a deferred-work ledger, correct-course, and retrospective
  all exist upstream under the same or similar names. Treat these as shared concepts,
  not leanwheel-only divergences.

### What genuinely still differs

- **Agent personas came back upstream.** The August 2026 revision of this section said
  personas were gone; v7 ships six `bmad-agent-*` persona skills (analyst, architect, dev,
  pm, po, ux-designer), and "Sofia the Product Owner" (`bmad-agent-po`) replaced
  `bmad-spec`, `bmad-ticket`, and `bmad-correct-course` outright. Leanwheel has none.
- **Per-invocation weight.** Upstream retained JIT step files, per-skill
  `customize.toml`, added `bmod.toml` module records, and routes every rendered skill
  through `render_skill.py` via `uv` with **Python 3.11+ as a hard requirement** — a
  skill halts without `uv`. `bmad-build` is still `step-01` … `step-05` plus
  `workflow.md`. The upstream `skills/` tree is ~3.6 MB against leanwheel's ~1.1 MB; two
  single upstream skills (`bmad` hub ~476 KB, `bmad-toolsmith` ~540 KB) each approach half
  of leanwheel's entire skill set. The leanwheel equivalent of Build is a single ~20 KB
  `SKILL.md` plus a ~4 KB agent file.
- **Verifiable artifacts over guardrails (DD-01)** — named report fields checked by
  zero-token orchestrator shell gates (`sabotage.sh`, `ledger.sh`, `budget.sh`,
  field-protected stubs) — has no upstream analogue. Upstream's closest move is the same
  instinct applied to bookkeeping: deterministic `sprint_plan.py` and `tickets.py`.
- **Sprint state:** upstream is replacing `sprint-status.yaml` with a **ticket tree**
  (`tickets.toml`, per-ticket plan files carrying `status` in frontmatter, a `tickets.py`
  script, an "active initiative" folder, and a migration command); leanwheel still uses
  GitHub issue labels and `docs/epics.md`.
- **Leanwheel-only:** the subtracted/deduplicated epic-boundary manual test plan with
  physical-device routing (DD-31), the sabotage fail-first gate proof (DD-11), per-phase
  model and effort routing (Opus only for Swift dev, Haiku for docs prose), and the
  observability ledger. **Upstream-only:** the zero-token deterministic control loop,
  declarative retry/oscillation policy, environment-fault probes, multi-CLI support
  (Codex, Gemini, Copilot, etc.), and skill-level evals.

### Worth porting as an idea (DD-01 style), October 2026 worklist

Items 1–3 landed as DD-80 (ported as ideas, stack-agnostic — the environment probe is a
project-declared `## Probe` command, not a Swift-only check). Item 4 was judged low value;
item 5 stands.

1. **Verification-gap pass in `/code-review`** — the coverage question ("would any test
   fail?") with the October tightening (only gaps a named regression test could catch;
   report stale tests that assert the pre-fix outcome). Pass C covers edge cases but
   nothing asks the coverage question today; it could also feed the eval BUILD step.
2. **Per-finding verdict + evidence and a scored re-review trigger** — check that every
   finding gets a logged disposition and that the follow-up decision is a formula.
3. **Environment fault ≠ story failure** — a probe before the Build & Test Gate / `sim.sh`
   and a reserved verify exit code, with a ledger field, so flakes don't charge a story.
4. **Retro action items → `docs/deferred-items.md`** — `/retrospective` and
   `/epic-flywheel` file open action items into the deferred ledger at the epic boundary.
5. (Standing) move more of the epic loop's mechanical bookkeeping — retry budgets,
   oscillation detection, journaled resumable run state — into a script the orchestrator
   calls, the way `gh-track.sh` and `sabotage.sh` already moved tracking and gate-proof
   off the model.

---

## Relationship to BMAD

This repo has no maintained fork of upstream. It's a standalone, deliberately leaner port. The upstream [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) has itself shed the activation ceremony since v6 (see the section above), but it still ships agent personas, JIT step files, per-skill TOML customization, and a `uv`/Python-backed script-rendering indirection — all of which add real per-invocation weight and are absent here by design. Upstream files are never copied directly into this repo for that reason; an upstream `SKILL.md` brings that infrastructure (step files, `customize.toml`, `render_skill.py`) along with it.

### Checking for upstream improvements

Periodically clone the upstream repo and compare it against `.claude/skills/` to see if anything genuinely new is worth porting — a capability, not a file:

```bash
git clone https://github.com/bmad-code-org/BMAD-METHOD /tmp/BMAD-METHOD
```

Because the file structures don't match (upstream's SKILL.md + step files + customize.toml + renderer vs. this repo's single-pass `SKILL.md`), a mechanical `diff` isn't useful. The practical approach is to hand the comparison to an AI assistant — but lead it with this repo's token-minimization philosophy first, or it will surface upstream's ceremony and customization layers as "missing features" rather than recognizing them as the overhead this project intentionally cut. Example prompt to build from:

```
I maintain leanwheel-skills, a token-efficient port of the BMAD Method for Claude Code.
It deliberately strips upstream's per-invocation infrastructure — JIT step files,
per-skill customize.toml, and the render_skill.py indirection (and the agent personas, plus
the pre-v6 activation ceremony, which upstream has since dropped) —
replacing them with plain-English rules in CLAUDE.md and single-pass inline skill files.
Both repos now use uppercase SKILL.md, but the file structures still don't correspond.
Full rationale is in guide/comparison.md, including an "Upstream state as of October
2026" section recording the last verified upstream snapshot — start there and update it.

Compare /tmp/BMAD-METHOD (upstream) against .claude/skills/ in this repo. For each
upstream skill, tell me:
1. Any genuinely new capability or bugfix not present here
2. Whether porting it would require re-adding ceremony/infrastructure this repo cut
   (if so, propose a lean equivalent instead of importing it wholesale)
3. Which local skill file(s) would need to change, and a one-paragraph plan — not a
   direct file copy
Skip anything that's purely structural/ceremonial with no functional difference.
```

Treat the output as a worklist, not a patch. For each item: read it, decide whether it fixes a real problem or adds genuine value, then port the *idea* into the equivalent `SKILL.md` — checking it against the [Local Customizations by Skill](../CLAUDE.md#local-customizations-by-skill) section in CLAUDE.md first so you don't clobber an intentional local divergence.

**The divergence will grow over time**, and that's expected — both projects evolve independently, and upstream may restructure significantly. Treat upstream as an ideas source, not a merge target.

---

## Relationship to ponytail

The simplicity / anti-over-engineering layer is the one piece **not** sourced from BMAD. It's an idea-only port of [ponytail](https://github.com/DietrichGebert/ponytail) (MIT): the 7-rung laziness ladder (appended to every `CLAUDE.md`), the delete-first review pass (code-review Pass F), and the `leanwheel:` deliberate-corner-cut marker (harvested by `/retrospective`). As with BMAD, no files were copied — and ponytail's own ceremony was left out: its lite/full/ultra **intensity dial** and its benchmark **scoreboard** aren't ported, and rather than a standalone audit skill the lens folds into `/spec` (architecture rendering), `/create-story`, `/dev-story`, `/code-review`, `/swift-audit`, `/web-audit`, and `/retrospective`.
