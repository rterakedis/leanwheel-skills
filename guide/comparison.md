[← Back to README](../README.md)

## What Was Cut vs Original BMAD

| Cut | Why |
|-----|-----|
| Activation ceremony (config.yaml, resolve_customization.py, 6-step boot) | Ran on every skill invocation even with zero customizations — pure overhead |
| Three-tier TOML customization surface | Replaced by plain-English rules in `CLAUDE.md` |
| Sprint-status.yaml | Replaced by GitHub issue labels — same visibility, no extra file |
| BMAD agent personas (bmad-agent-pm, bmad-agent-architect, etc.) | Extra persona tokens on every skill invocation — not needed for solo use |
| Step-file JIT architecture (8 files for architecture alone) | Collapsed to single inline workflow |
| 1,512-line retrospective | Replaced with 7 focused questions (5 upstream + 2 local additions) |
| PRD decision log + addendum | Captured inline in story Dev Notes instead |
| HTML validation reports | Overkill for personal workflow |
| UX/design agent persona (Sally) | Agent persona tokens not needed; UX workflow ported as `/ux` skill with Apple HIG + SwiftUI + responsive web support |
| Checkpoint preview | Covered by code-review's 3-pass inline review |
| E2E test generation | Handled by story-level testing requirements in Dev Notes |

## What BMAD-LITE Added That Original BMAD Didn't Have

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
| `/product-brief`, `/forge-idea`, `/research` | A pre-PRD idea-formation layer, reintroduced after initially being cut as ceremony-only (see prior revision of this table). `/prd`'s "describe the product, one prompt" Step 1 was a real gap when the user doesn't have a formed idea yet — `/product-brief` diverges (brainstorm) then distills (writes `docs/project/brief.md`) in one skill; `/forge-idea` adversarially pressure-tests it; `/research` grounds decisions in cited web research. All three are lean single-pass ports, not direct copies — upstream's three separate research-variant skills collapse into one with a type selector, upstream's CSV-served 100+-technique brainstorming catalog collapses into a small inline list |

---

## Relationship to BMAD

This repo has no maintained fork of upstream. It's a standalone, deliberately leaner port: the upstream [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) framework ships an activation ceremony, three-tier TOML customization, agent personas, and JIT step-file loading — all of which add real per-invocation token cost and are absent here by design (see "What Was Cut" above). Upstream files are never copied directly into this repo for that reason; a `skill.md` from upstream brings that infrastructure along with it.

### Checking for upstream improvements

Periodically clone the upstream repo and compare it against `.claude/skills/` to see if anything genuinely new is worth porting — a capability, not a file:

```bash
git clone https://github.com/bmad-code-org/BMAD-METHOD /tmp/BMAD-METHOD
```

Because the file structures don't match (different filenames, ceremony-wrapped skill files vs. this repo's single-pass `SKILL.md`), a mechanical `diff` isn't useful. The practical approach is to hand the comparison to an AI assistant — but lead it with this repo's token-minimization philosophy first, or it will surface upstream's ceremony and customization layers as "missing features" rather than recognizing them as the overhead this project intentionally cut. Example prompt to build from:

```
I maintain bmad-lite-skills, a token-efficient port of the BMAD Method for Claude Code.
It deliberately strips: the per-invocation activation ceremony, three-tier TOML
customization, agent persona overhead, and JIT step-file loading — replacing them with
plain-English rules in CLAUDE.md and single-pass inline skill files. Full rationale is
in guide/comparison.md and guide/features.md of this repo.

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
