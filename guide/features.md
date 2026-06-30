[← Back to README](../README.md)

## What this is

This is a standalone skills library for [Claude Code](https://claude.ai/code). It is a port and simplification of the [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) — a structured approach to building software with AI that separates planning from implementation and keeps each AI session focused on one well-scoped task.

> **New to this?** BMAD is a way of using AI to build software in a structured, repeatable way.
> You write planning docs first, then AI helps you implement one small piece at a time.
> Each "skill" is a command you give Claude — like `/prd` to write requirements or `/dev-story` to write code.

**BMAD-LITE-SKILLS removes:**
- The activation ceremony that ran on every skill invocation (~700 tokens/call)
- Three-tier TOML customization infrastructure
- Agent persona overhead
- Sprint-status.yaml (replaced by GitHub issue labels)

**BMAD-LITE-SKILLS keeps:**
- The full planning flywheel: (Idea →) PRD → UX → Architecture → Epics → Stories → Dev → Review
- Epic context caching (~76% token reduction on `/create-story` after the first story)
- Inline code review (no separate session startup cost)
- GitHub issue + milestone tracking
- Security review, investigate, retrospective, correct-course

**BMAD-LITE-SKILLS adds:**
- **Pre-PRD idea-formation layer**: `/product-brief` (diverge — brainstorm if no idea yet — then distill into `docs/project/brief.md`, which `/prd` reads automatically), `/forge-idea` (adversarial pressure-test, standalone or chained from `/product-brief`, resolves to Hardened/Killed/Clearer), and `/research` (cited technical/domain/market web research feeding any planning skill)
- `/ux` skill with Apple platform support (SwiftUI, HIG compliance checklist, multi-target cascade iPhone → iPad → Mac) and responsive web
- Epic-scoped retrospectives with output in `docs/epics/`
- BMAD migration flow (`/setup migrate` + `/setup clean`)
- Consolidated `docs/` layout — all artifacts under `docs/`, nothing at project root except `AGENTS.md` + `CLAUDE.md`
- Swift/Apple platform guidance system: `/setup` scaffolds `docs/setup/swift/` with sectioned best-practice reference docs (state management, concurrency, architecture, UI composition, testing, anti-patterns, plus iPadOS- and macOS-specific files); a 37-line guardrails block is appended to `CLAUDE.md`; `/dev-story` and `/code-review` read the relevant sections before acting
- `/refresh-swift` — researches current Swift/SwiftUI/platform patterns from primary sources (Hacking with Swift, Swift with Majid, SwiftLee, Apple WWDC docs, Point-Free) and updates both `docs/setup/swift/` and the skills repo stubs; offers to chain into `/swift-audit`
- `/swift-audit` — audits planning docs, story files, and Swift source code against `docs/setup/swift/` guidance; produces a triaged remediation file in `docs/maintainer/` ready for `/dev-story`
- **Web/SSG guidance system** (mirror of the Swift system): `/setup` scaffolds `docs/setup/web/` with sectioned reference docs (CSS design system, accessibility + SEO, anti-patterns, plus Astro- or Hugo-specific files) and appends a web guardrails block to `CLAUDE.md`; `/dev-story`, `/code-review`, and `/web-audit` read the relevant sections before acting
- `/refresh-web` — researches current web platform / CSS / Astro / Hugo patterns from primary sources (web.dev, MDN, Astro docs, Hugo docs, CSS-Tricks, Smashing, WAI) and updates `docs/setup/web/` + the skills repo stubs; offers to chain into `/web-audit`
- `/web-audit` — audits planning docs, story files, templates, styles, and markup against `docs/setup/web/` guidance and `docs/ux/DESIGN.md` tokens; produces a triaged remediation file in `docs/maintainer/` ready for `/dev-story`
- **Closed design loop**: `/create-story` extracts a per-story **Design Contract** (tokens, component specs, required states, reuse list) from `docs/ux/` into Dev Notes; `/dev-story` implements against it and runs `/design-verify` (build + screenshots, light/dark, Dynamic Type / responsive widths) before review; `/code-review` runs a Design Compliance pass and maintains a `docs/ux/components-built.md` inventory so later stories reuse components instead of reinventing them; `/check-readiness` blocks UI stories that have no design coverage
- `/ux` content-site (SSG) preset for Astro/Hugo sites — typography-first tokens, content-model → layout mapping, and a performance budget (Core Web Vitals + per-page JS budget) decided at design time
- **Subagent delegation via `/story-flywheel`**: spawns isolated `bmad-story-creator`, `bmad-story-developer`, and `bmad-story-reviewer` agents — each phase runs in its own context window so heavy reads (PRD, architecture, story files) never accumulate in the main thread. A fourth agent, `bmad-docs-sync` (pinned to **Haiku**), keeps the project's docs current off the expensive model
- **Living documentation via `/docs-sync`**: dev/review discoveries flow back into the docs automatically — the human stand-up / operate / database guides (`docs/setup/`, `docs/maintainer/`, `docs/sql/`) grow as code changes, and durable architectural learnings are promoted into `docs/architecture.md` at the epic boundary. Runs on Haiku so it stays cheap
- **Deterministic guardrail hooks** (zero model tokens): `guard-secrets.sh` blocks hardcoded secrets at write time; `guard-design-tokens.sh` warns on off-token colors; `log-activity.sh` streams tool-call telemetry to `docs/metrics/activity.jsonl`; wired via `.claude/hooks/` by `/setup`
- **Observability ledger** (`docs/metrics/flywheel-ledger.jsonl`): each `/dev-story` and `/code-review` pass appends a structured line (story, model, build result, evals pass rate, finding counts) — queryable with `jq` to track per-story quality and model cost over time
- **Cumulative eval regression net** (`docs/evals/`): `/create-story` seeds `type: command` eval cases from ACs; `/dev-story` runs them (zero-token shell execution) and enables the case when the test lands; a failing eval on a later story is a regression and blocks close just like a red build
- `/upgrade-project` — detection-based sync for existing projects: scans for missing hooks, stubs, evals/metrics dirs, and CLAUDE.md sections; classifies each item as ADD / REFRESH / CONFLICT / OK; previews before applying; never overwrites locally edited content; writes `.bmad-lite/manifest.json` for future runs
- `/epic-flywheel` — autonomous epic orchestration layer above `/story-flywheel`: drives a whole epic from "not started" to "implemented, reviewed, verified together" with granular commit-per-step (create → commit → dev → commit → review+patch → commit), within-epic auto-advance on green stories, an Epic Boundary Gate (whole-project build+test, cumulative evals RUN across all epics, invariant + deferred sweeps — HALTs for help on any failure), deferred-item re-homing, a rolled-up LLM-deduplicated test plan split into simulator/local-runnable vs physical-device-required cases (physical items persist to `docs/testing/physical-device-backlog.md`), and a mandatory retrospective reminder at the boundary
- **`scripts/commit-push.sh`** — zero-reasoning commit helper scaffolded by `/setup` and `/upgrade-project` into every project: stages, commits (with the Co-Authored-By trailer), and pushes to the current branch in one call; supports staged-tracked-only (default), specific files, or `--all`
