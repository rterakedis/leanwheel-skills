[← Back to README](../README.md)

## What Was Cut vs Original BMAD

> **Historical note.** The two tables below record the port decisions against the upstream
> BMAD that existed when this repo was created (the v4/v5 YAML/XML-workflow era). Upstream
> has since been rebuilt — see [Upstream state as of August 2026](#upstream-state-as-of-august-2026)
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
| Checkpoint preview | Covered by code-review's 3-pass inline review |
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

## Upstream state as of August 2026

Upstream shipped **v6.0.0 stable (~March 2026)** and replaced its entire legacy
architecture with a skills-based one, then kept moving fast (v6.11 by August 2026).
Several claims elsewhere in this doc's history — and several rows in the tables above —
describe an upstream that no longer exists. Current facts, verified against the upstream
repo and changelog (August 2026):

### What upstream cut too (convergence on lean)

- **Activation ceremony and agent personas are gone upstream as well.** Personas were
  consolidated into a single developer agent (v6.0); the persona directories that remain
  are skills, not per-invocation persona loads.
- **The SM → new chat → DEV → new chat → QA cycle is gone.** There is no upstream
  create-story or dev-story anymore. v6.11 renamed Quick Dev to `bmad-build` — "the one
  official way BMad implements code" — with `bmad-build-auto` as its unattended variant.
- **Uppercase `SKILL.md` is now the upstream convention** (since v6.1). The old
  lowercase-`skill.md` distinction this repo's docs cited is obsolete.
- **Test Architect (TEA) moved out** to an external enterprise module (v6.9);
  `bmad-qa-generate-e2e-tests` remains in the shipped set.

### What upstream added that parallels leanwheel

- **`bmad-loop` (v6.10, July 2026, separate repo)** is upstream's epic flywheel: an
  unattended pick-story → implement → verify → gated adversarial review → re-verify →
  commit loop with deferred-work sweeps at epic boundaries. Its architecture is the
  *inverse* of `/epic-flywheel`: a deterministic pure-Python orchestrator (no LLM in the
  control loop) that spawns a fresh coding-agent CLI session per step in tmux, driven by
  a `policy.toml` (retry budgets, oscillation detection), with resumable journaled run
  state and git-worktree isolation. Leanwheel's orchestrator is an in-session LLM thread
  holding short structured subagent reports, which lets it make cheap mid-loop judgment
  calls (review-skip on clean stories, blast-radius triggers, the boundary test-plan
  subtract) that a Python loop cannot.
- **Real programmatic subagents.** Since v6.2–6.4, upstream's code review spawns parallel
  review-layer subagents (Blind Hunter / Edge Case Hunter / Acceptance Auditor) with a
  deliberate asymmetry — subagents report, the orchestrating session traces consequences
  and triages (`intent_gap`/`bad_spec`/`patch`/`defer`). Party-mode integrated Claude
  Code Agent Teams by v6.9. No evidence upstream ships `.claude/agents/*.md` agent
  definition files; leanwheel's four pinned `lw-*` agents with report contracts and
  model/effort frontmatter remain a structural difference.
- **Shared concepts, direction of influence unknown.** forge-idea, a DESIGN.md +
  EXPERIENCE.md dual UX spine, a deferred-work ledger, correct-course, and retrospective
  all now exist upstream under the same or similar names. Treat these as shared concepts,
  not leanwheel-only divergences.

### What genuinely still differs

- **Per-invocation weight.** Upstream retained JIT step files, per-skill
  `customize.toml` (~7KB), and added a content-addressed `render_skill.py` snapshot
  renderer — `bmad-build` alone spans ~55–60KB of step/config files. The leanwheel
  equivalent is a single ~200-line `SKILL.md` plus a ~70-line agent file; the entire
  agent layer is 219 lines.
- **Verifiable artifacts over guardrails (DD-01)** — named report fields checked by
  zero-token orchestrator shell gates — has no upstream analogue.
- **Sprint state:** upstream's `sprint-status.yaml` is alive and is `bmad-loop`'s story
  source; leanwheel still uses GitHub issue labels instead.
- **Leanwheel-only:** the subtracted/deduplicated epic-boundary manual test plan with
  physical-device routing (DD-31), the sabotage fail-first gate proof (DD-11), per-phase
  model routing (Opus only for Swift dev, Haiku for docs prose), and the observability
  ledger. **Upstream-only:** the zero-token deterministic control loop, declarative
  retry/oscillation policy, and multi-CLI support (Codex, Gemini, Copilot, etc.).
- **Worth porting as an idea (DD-01 style):** moving more of the epic loop's mechanical
  bookkeeping — retry budgets, oscillation detection, journaled resumable run state —
  into a script the orchestrator calls, the way `gh-track.sh` and `sabotage.sh` already
  moved tracking and gate-proof off the model.

---

## Relationship to BMAD

This repo has no maintained fork of upstream. It's a standalone, deliberately leaner port. The upstream [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) has itself shed the activation ceremony and persona overhead since v6 (see the section above), but it still ships JIT step files, per-skill TOML customization, and a script-rendering indirection — all of which add real per-invocation weight and are absent here by design. Upstream files are never copied directly into this repo for that reason; an upstream `SKILL.md` brings that infrastructure (step files, `customize.toml`, `render_skill.py`) along with it.

### Checking for upstream improvements

Periodically clone the upstream repo and compare it against `.claude/skills/` to see if anything genuinely new is worth porting — a capability, not a file:

```bash
git clone https://github.com/bmad-code-org/BMAD-METHOD /tmp/BMAD-METHOD
```

Because the file structures don't match (upstream's SKILL.md + step files + customize.toml + renderer vs. this repo's single-pass `SKILL.md`), a mechanical `diff` isn't useful. The practical approach is to hand the comparison to an AI assistant — but lead it with this repo's token-minimization philosophy first, or it will surface upstream's ceremony and customization layers as "missing features" rather than recognizing them as the overhead this project intentionally cut. Example prompt to build from:

```
I maintain leanwheel-skills, a token-efficient port of the BMAD Method for Claude Code.
It deliberately strips upstream's per-invocation infrastructure — JIT step files,
per-skill customize.toml, and the render_skill.py indirection (and, historically, the
pre-v6 activation ceremony and agent personas, which upstream has since dropped too) —
replacing them with plain-English rules in CLAUDE.md and single-pass inline skill files.
Both repos now use uppercase SKILL.md, but the file structures still don't correspond.
Full rationale is in guide/comparison.md, including an "Upstream state as of August
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
