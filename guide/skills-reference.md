[← Back to README](../README.md)

## All Skills

**Project Initialization**
| Invocation | What it does |
|------------|-------------|
| `/setup` | Detects project state and routes automatically: finds `_bmad/` → prompts to run migrate + clean; finds existing `docs/` → idempotent re-run; finds neither → greenfield scaffold of `docs/`, `AGENTS.md`, `CLAUDE.md`. For Apple platform projects, asks which platforms (iOS / iPadOS / macOS, multi-select), appends a Swift/SwiftUI guardrails block to `CLAUDE.md`, and scaffolds `docs/setup/swift/` with the 6 shared guidance files plus `ipados-specific.md` and/or `macos-specific.md` as applicable. For web projects (web app / Astro / Hugo / other SSG), appends a Web guardrails block to `CLAUDE.md` and scaffolds `docs/setup/web/` with the 3 shared guidance files plus `astro.md` or `hugo.md` as applicable. |
| `/setup migrate` | Migrate a full-BMAD project to BMAD-LITE — reads `_bmad/config.toml` to locate artifacts, moves planning docs + stories into the BMAD-LITE `docs/` layout, stamps `Status:` into each story file from `sprint-status.yaml`, updates `AGENTS.md` + `CLAUDE.md`, then attempts GitHub label setup + issue backfill inline (gracefully skipped if auth not configured). Non-destructive — never deletes. |
| `/setup clean` | Remove BMAD infrastructure after a successful migrate — confirms before deleting each target: `_bmad/`, `sprint-status.yaml`, and optionally `src/bmm-skills/` |
| `/github-tracking setup` | One-time: GitHub auth + create the four status labels |
| `/github-tracking backfill` | Retroactively create GitHub issues for stories written before tracking was configured |
| `/upgrade-project` | Detection-based sync for projects scaffolded by older versions of bmad-lite-skills. Scans for missing hooks, stubs, evals/metrics dirs, and CLAUDE.md sections; classifies each as ADD / REFRESH / CONFLICT / OK; shows a plan table and waits for confirmation before applying anything. CONFLICT = locally edited file — left untouched, flagged for manual merge. Writes `.bmad-lite/manifest.json` for future runs. Run whenever you pull new bmad-lite-skills changes. |

**Pre-Planning** *(optional — for when the idea isn't formed yet)*
| Invocation | What it does |
|------------|-------------|
| `/product-brief` | Two motions in one skill: **diverge** (brainstorm, only if the user has no formed idea yet — stance choice, 3-4 techniques, explicit Converge phase) then **distill** (write `docs/project/brief.md`, Fast/Coaching path, `[ASSUMPTION]` tagging, overflow detail to `brief-addendum.md`). Ends by offering `/forge-idea` as a pressure-test before finalizing. Auto-detects create/update/validate like `/ux`. |
| `/forge-idea` | Adversarially pressure-tests a formed idea via persona cross-examination (one outside-skeptic voice per turn — competitor, buyer, domain expert, support engineer) until it resolves to **Hardened** (writes `docs/project/forged-idea-{slug}.md`), **Killed** (idea didn't hold up, loops back to `/product-brief`'s diverge flow), or **Clearer** (no artifact). Invocable standalone or chained from the end of `/product-brief`. |
| `/research` | Cited, web-grounded research — technical (stack/integration/architecture), domain (industry/regulatory/competitive), or market (customers/decision journey) — writes `docs/project/research/{type}-{slug}-{date}.md` to ground `/product-brief`, `/prd`, or `/architecture` in real external facts instead of model assumptions. |

**Planning**
| Invocation | What it does |
|------------|-------------|
| `/prd` | Auto-detects intent: **create** (no PRD yet), **update** (PRD exists), or **validate** (critique only). On create, reads `docs/project/brief.md` if present and confirms it back instead of asking the user to describe the product cold. |
| `/prd update` | Explicit update — reads `docs/project/` for upstream changes, then checks for in-progress/done stories and recommends `/correct-course` if any are affected |
| `/prd validate` | Critique only — runs the PRD checklist and reports findings without modifying the file |
| `/architecture` | Create or update `docs/architecture.md` — reads `docs/project/` for technical inputs |
| `/ux` | Create, update, or validate UX design specs — produces `docs/ux/DESIGN.md` (visual identity: colors, typography, components) and `docs/ux/EXPERIENCE.md` (IA, behavior, states, interactions, accessibility, key flows). Primary surfaces: **responsive web apps**, **content sites / SSGs** (Astro · Hugo — typography-first tokens, content-model → layout mapping, performance budget with per-page JS justification), and **Apple platforms** (iOS · iPadOS · macOS via SwiftUI). Apple output includes a full HIG compliance checklist, SwiftUI component map, and multi-target layout cascade (iPhone → iPad → Mac). Android deferred as `[FUTURE: Android]`. Renders inline HTML mockups on demand to help visualize color and layout decisions. |
| `/ux update` | Explicit update to existing spines — reads change signal, surfaces conflicts with prior decisions, re-triages HIG checklist items |
| `/ux validate` | Critique only — runs the UX checklist across flow coverage, token completeness, component coverage, state coverage, Apple HIG compliance, and responsive breakpoints |
| `/discover` | Brownfield only: reverse-engineer existing codebase → `prd.md` + `architecture.md` + `CLAUDE.md` |
| `/epics` | Break the PRD into epics and stories, create GitHub milestones |

**Planning Gate**
| Invocation | What it does |
|------------|-------------|
| `/check-readiness` | Validate PRD + architecture + epics are aligned — checks FR coverage, AC testability, story independence, architecture consistency, MVP scope drift, security coverage, cross-epic runtime dependencies, testing targets derived from architecture, and UX alignment (UI stories must map to EXPERIENCE.md surfaces; design tokens ready before implementation) |

**Dev Flywheel**
| Invocation | What it does |
|------------|-------------|
| `/story-flywheel` | Fully automated create → dev → review loop. Spawns isolated subagents (`bmad-story-creator` → `bmad-story-developer` → `bmad-story-reviewer`) so each phase's heavy reads stay in a throwaway context, keeping the main thread lean. On Swift projects, emits **MODEL SWITCH GATE** hard-stops before each phase with a per-story model plan (Sonnet for create, Opus for dev, Sonnet for review); user types "ready" after switching in the UI. On non-Swift projects, runs fully automated with no gates. Pauses for human decisions surfaced by the Clarification Gate in Phase 1. |
| `/story-flywheel {epic}-{story}` | Run the flywheel on a specific story, e.g. `/story-flywheel 2-3` |
| `/epic-flywheel` | Autonomous, epic-scoped orchestration layer above `/story-flywheel`. Drives a whole epic from "not started" to "implemented + reviewed + verified" with: granular commit-per-step (create → commit → dev → commit → review+patch → commit, using `scripts/commit-push.sh` when present); within-epic auto-advance on fully-green stories; an **Epic Boundary Gate** (whole-project build+test, cumulative `evals` RUN across all epics, invariant sweep, two-pass deferred sweep — any failure HALTs); deferred-item re-homing at the boundary; a rolled-up LLM-deduplicated test plan written to `docs/epics/epic-{N}-test-plan.md` with every test classified as simulator/local-runnable vs physical-device-required; physical-device items persist to `docs/testing/physical-device-backlog.md`; boundary report always surfaces a mandatory retrospective reminder (skipping requires explicit confirmation). |
| `/epic-flywheel {N}` | Run the flywheel on a specific epic number, e.g. `/epic-flywheel 2` |
| `/evals build` | Append (or flip `enabled: true` on) `type: command` eval cases derived from a story's ACs and Behavior Contract invariants — run by `/create-story` and `/dev-story` automatically |
| `/evals run` | Execute all enabled eval cases for a story's epic — zero-token shell execution; failing case = regression, blocks story close |
| `/evals score` | Score the last run and emit a pass/fail rubric line — integrated into `/code-review`'s final gate |
| `/create-story` | Spec the next `ready-for-dev` story (auto-detected from `docs/epics.md`); performs a cross-epic runtime dependency check before writing. For UI stories, extracts a **Design Contract** from `docs/ux/` into Dev Notes (tokens, component specs, required states, reuse list from `components-built.md`) so dev sessions never re-read the UX specs |
| `/create-story {epic}-{story}` | Spec a specific story, e.g. `/create-story 2-3` |
| `/create-story refresh-cache` | Force-regenerate the epic context cache even if timestamps look fresh — use after editing `prd.md` or `architecture.md` mid-epic |
| `/dev-story` | Implement the first `ready-for-dev` story found in `docs/epics/`. On Apple platform projects, reads the relevant `docs/setup/swift/` guidance files before starting (scoped to the story's tasks); on web projects, reads the relevant `docs/setup/web/` files; always reads `anti-patterns.md` if present. UI stories implement against the embedded Design Contract and run `/design-verify` (screenshots vs contract) after DoD. Code-review (incl. design Pass E) + security Pass D run inline at the end. |
| `/dev-story {path}` | Implement a specific story file, e.g. `/dev-story docs/epics/1-2-user-auth.md` |
| `/code-review` | Standalone review — auto-detects a story in `review` status, or reviews current branch vs main. On Apple platform projects, reads `anti-patterns.md` + `state-management.md` as rejection criteria (plus iPadOS/macOS files when relevant); on web projects, reads `docs/setup/web/` anti-patterns + CSS guidance. UI diffs get a **Design Compliance pass** against DESIGN.md tokens and required states, and new reusable components are recorded in `docs/ux/components-built.md`. |
| `/code-review {branch}` | Review a specific branch vs main, e.g. `/code-review feature/payments` |
| `/code-review {commit}` | Review a specific commit range, e.g. `/code-review abc123..def456` |
| `/code-review {story-file}` | Review the diff associated with a specific story file |
| `/quick-dev` | Describe a one-off feature or fix — skill scopes it, writes a spec, implements, and updates docs |
| `/design-verify` | Visually verify the working tree's UI changes against `docs/ux/` — builds/serves, screenshots (light/dark, Dynamic Type or mobile/desktop widths), reports mismatches by severity. Runs automatically inside `/dev-story` for UI stories; invocable standalone. |
| `/docs-sync` | Composable documentation-maintenance skill (single source of truth for doc feedback). Three ops: **OPERATIONAL** grows the human stand-up / operate / database guides (`docs/setup/`, `docs/maintainer/`, `docs/sql/`) from a changed-file set — creating new topical pages and wiring them into each area's `index.md`, gated on infra-shaped changes (dependencies, env, migrations, scripts, deploy/CI, services); **PROMOTE** lifts durable project-canonical learnings from `docs/epics/epic-{N}-context.md` into `docs/architecture.md`; **DRIFT** flags (never edits) stale `docs/setup/swift\|web/` coding guidance, recommending `/refresh-swift\|web`. Never writes the refresh-owned `swift/web` guidance and never scaffolds an absent area. Runs on the `bmad-docs-sync` subagent (**Haiku**) so this mechanical work never lands on the dev model; called automatically by `/dev-story`, `/quick-dev`, `/code-review`, `/epic-flywheel`, and `/retrospective`. Directly invocable to catch the working tree up after manual work. |

**Mid-Sprint Management**
| Invocation | What it does |
|------------|-------------|
| `/investigate` | Start a new investigation — accepts a description, error message, stack trace, ticket ID, or file/module name |
| `/investigate {slug}` | Resume an existing investigation from `docs/investigations/{slug}.md` |
| `/correct-course` | Triggered by a known change — updates docs, schedules remediation stories forward, clears deferred items |
| `/deferred` | Show the full `docs/deferred-items.md` log with status of each scheduled story. See [guide/deferred-items.md](deferred-items.md) for the full lifecycle (logging, scheduling, re-homing). |

**Swift / Apple Platform**
| Invocation | What it does |
|------------|-------------|
| `/refresh-swift` | Research current Swift language, SwiftUI, concurrency, testing, and platform-specific patterns from primary sources (Hacking with Swift, Swift with Majid, SwiftLee, Apple WWDC sample apps, Point-Free). Updates `docs/setup/swift/` in the current project and the corresponding stubs in the skills repo so new projects get the same content. Scope: current stable iOS/macOS releases only — pre-release APIs are hard-excluded. After updating, offers to chain directly into `/swift-audit`. |
| `/swift-audit` | Audit the full project against the guidance in `docs/setup/swift/`. Scans `architecture.md`, `prd.md`, `epics.md`, all story files, and all `.swift` source files (including hardcoded-color checks against `docs/ux/DESIGN.md` tokens). Findings are triaged by scope (`DOC-ARCH`, `DOC-PRD`, `DOC-EPICS`, `STORY`, `CODE`) and severity (`HIGH` / `MEDIUM` / `LOW`). Writes a single remediation file to `docs/maintainer/swift-audit-{date}.md` — one AC per finding — ready for `/dev-story`. Requires `docs/setup/swift/` to exist. |

**Web / SSG**
| Invocation | What it does |
|------------|-------------|
| `/refresh-web` | Research current web platform, CSS, Astro, and Hugo best practices from primary sources (web.dev, MDN, Astro docs/blog, Hugo docs/releases, CSS-Tricks, Smashing Magazine, W3C WAI). Updates `docs/setup/web/` in the current project and the corresponding stubs in the skills repo. Scope: Baseline widely-available platform features and current stable Astro/Hugo majors only — experimental features are hard-excluded. After updating, offers to chain directly into `/web-audit`. |
| `/web-audit` | Audit the full project against the guidance in `docs/setup/web/` and the design tokens in `docs/ux/DESIGN.md`. Scans planning docs, story files, templates (`.astro`, Hugo `layouts/`), stylesheets, and markup — framework-aware (Astro hydration directives, Hugo hardcoded paths). Findings triaged by scope and severity. Writes a single remediation file to `docs/maintainer/web-audit-{date}.md` — one AC per finding — ready for `/dev-story`. Requires `docs/setup/web/` to exist. |

**Security**
| Invocation | What it does |
|------------|-------------|
| `/security-review` | Prompts: full project sweep or scoped? Runs OWASP + LLM checklists, auto-schedules critical/high findings |
| `/security-review full` | Full project sweep — all checklist categories against the entire codebase |
| `/security-review story {path}` | Scoped to a specific story's diff, e.g. `/security-review story docs/epics/1-3-payments.md` |

**Tracking & Retrospective**
| Invocation | What it does |
|------------|-------------|
| `/status` | Show all epics and stories via GitHub milestones — epic progress, story status at a glance |
| `/retrospective` | Facilitated **epic** retrospective (one per epic, not per sprint) — 7 questions scoped to the target epic's stories (including "what went well?" and a prior-retro conventions audit), updates `CLAUDE.md`, audits deferred items log for any unlogged `[Defer]` entries and verifies scheduled items are in open work, writes `docs/epics/epic-{n}-retro-{date}.md` |
| `/retrospective epic {n}` | Explicit epic target, e.g. `/retrospective epic 2` — skip auto-detection |
