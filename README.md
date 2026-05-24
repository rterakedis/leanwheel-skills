# bmad-lite-skills

A lean, token-efficient set of Claude Code skills for structured AI-assisted software development — designed to fit comfortably within Claude Pro's context budget while keeping the full value of the BMAD planning flywheel.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## What this is

This is a standalone skills library for [Claude Code](https://claude.ai/code). It is a port and simplification of the [BMAD Method](https://github.com/bmad-method/bmad) — a structured approach to building software with AI that separates planning from implementation and keeps each AI session focused on one well-scoped task.

> **New to this?** BMAD is a way of using AI to build software in a structured, repeatable way.
> You write planning docs first, then AI helps you implement one small piece at a time.
> Each "skill" is a command you give Claude — like `/prd` to write requirements or `/dev-story` to write code.

**BMAD-LITE-SKILLS removes:**
- The activation ceremony that ran on every skill invocation (~700 tokens/call)
- Three-tier TOML customization infrastructure
- Agent persona overhead
- Subagent pipelines (not available on Claude Pro)
- Sprint-status.yaml (replaced by GitHub issue labels)

**BMAD-LITE-SKILLS keeps:**
- The full planning flywheel: PRD → UX → Architecture → Epics → Stories → Dev → Review
- Epic context caching (~76% token reduction on `/create-story` after the first story)
- Inline code review (no separate session startup cost)
- GitHub issue + milestone tracking
- Security review, investigate, retrospective, correct-course

**BMAD-LITE-SKILLS adds:**
- `/ux` skill with Apple platform support (SwiftUI, HIG compliance checklist, multi-target cascade iPhone → iPad → Mac) and responsive web
- Epic-scoped retrospectives with output in `docs/epics/`
- BMAD migration flow (`/setup migrate` + `/setup clean`)
- Consolidated `docs/` layout — all artifacts under `docs/`, nothing at project root except `AGENTS.md` + `CLAUDE.md`

---

## Credit

This project is derived from and inspired by **[BMAD Method](https://github.com/bmad-method/bmad)** by BMad Code, LLC, used under the [MIT License](https://github.com/bmad-method/bmad/blob/main/LICENSE). The BMAD Method is a structured AI development workflow; this project ports its core planning flywheel into a leaner form optimized for Claude Pro's context budget.

BMad™ and BMad Method™ are trademarks of BMad Code, LLC. This project is not affiliated with or endorsed by BMad Code, LLC.

---

## How to use

These skills are designed to be **added to any Claude Code session as a workspace directory** — not copied into individual projects. Clone this repo once and reference it across all your projects.

### 1 — Clone once

```bash
git clone https://github.com/rterakedis/bmad-lite-skills ~/repos/bmad-lite-skills
```

Put it wherever you keep shared tools. The path doesn't matter as long as it's consistent.

### 2 — Add to your Claude Code session

At the start of any session, run:

```
/add-dir ~/repos/bmad-lite-skills
```

Claude can now read all skill files from that directory alongside your project.

### 3 — Wire up auto-loading (recommended)

To avoid running `/add-dir` manually every session, add it as a startup hook in your project's `.claude/settings.json`:

```json
{
  "hooks": {
    "startup": [
      "add-dir ~/repos/bmad-lite-skills"
    ]
  }
}
```

The `/setup` skill writes this hook for you when initializing a new project — just tell it where you cloned this repo.

### 4 — Invoke skills

Once the directory is added, invoke skills by name:

| Skill | What it does |
|---|---|
| `/setup` | Scaffold `docs/`, write `AGENTS.md` + `CLAUDE.md`, wire up auto-`/add-dir` hook |
| `/prd` | Create, update, or validate the Product Requirements Doc |
| `/ux` | Create UX design specs — responsive web + Apple platforms (SwiftUI + HIG) |
| `/architecture` | Create or update the architecture document |
| `/epics` | Break the PRD into epics and stories, create GitHub milestones |
| `/check-readiness` | Validate PRD + architecture + epics are aligned before coding |
| `/create-story` | Spec the next story with full dev context embedded |
| `/dev-story` | Implement a story — code review runs inline at the end |
| `/code-review` | Standalone adversarial review of current diff or a story |
| `/quick-dev` | One-off feature or fix without the full epic/story workflow |
| `/correct-course` | Handle mid-epic requirement changes or discovered bugs |
| `/investigate` | Start or resume a structured investigation case file |
| `/security-review` | OWASP + LLM security sweep, auto-schedules findings |
| `/status` | Show epic + story progress via GitHub milestones |
| `/retrospective` | Epic retrospective — 5 questions, updates `CLAUDE.md` |
| `/deferred` | View the deferred items log |
| `/github-tracking setup` | One-time GitHub auth + create status labels |
| `/github-tracking backfill` | Retroactively create GitHub issues for existing stories |
| `/discover` | Brownfield: reverse-engineer a codebase into docs |
| `/setup migrate` | Migrate a full-BMAD project to BMAD-LITE layout |
| `/setup clean` | Remove BMAD infrastructure after migration |

See [All Skills](#all-skills) below for full details on sub-parameters and behavior.

---

## Keeping skills up to date

```bash
cd ~/repos/bmad-lite-skills
git pull
```

All projects that reference this directory pick up the update immediately — nothing to copy or sync per project.

---

## Greenfield Process
*Use this when starting a brand-new project from scratch.*

```mermaid
flowchart TD
    A([🚀 New Project]) --> B

    subgraph ONCE ["Run Once Per Project"]
        B["/setup\nScaffold docs/ folder\nCreate AGENTS.md + CLAUDE.md"]
        B --> C["/github-tracking setup\nConnect to GitHub\nCreate status labels"]
    end

    C --> D

    subgraph PLAN ["Planning Phase — do this before writing any code"]
        D["/prd\nWrite the Product Requirements Doc\nWhat are we building and why?"]
        D --> DU["/ux\nWrite UX design specs\nDESIGN.md + EXPERIENCE.md\n(optional — skip for pure backend)"]
        DU --> E["/architecture\nWrite the Architecture Doc\nWhat tech stack, patterns, and structure?"]
        E --> F["/epics\nBreak the PRD into Epics and Stories\nCreates GitHub milestones automatically"]
        F --> FR["/check-readiness\nValidate FR coverage, AC quality\nand architecture alignment"]
    end

    FR --> G

    subgraph LOOP ["Dev Loop — repeat for every story"]
        G["/create-story\nSpec out the next story\nEmbeds everything the dev agent needs\nCreates a GitHub issue automatically"]
        G --> H["/dev-story\nAI implements the story\nChecks off tasks as it goes\nUpdates GitHub issue to in-progress"]
        H --> I["/code-review\nAdversarial review of the diff\nFinds bugs, missing ACs, edge cases\nCloses GitHub issue when clean"]
        I -->|"More stories\nto do?"| G
    end

    I -->|"Epic done?\nCheck /status"| J

    subgraph RETRO ["End of Epic"]
        J["/retrospective\nWhat worked? What didn't?\nUpdates CLAUDE.md with new conventions"]
    end

    J -->|"Start next epic"| G

    style ONCE fill:#e8f4f8,stroke:#2196F3
    style PLAN fill:#e8f8e8,stroke:#4CAF50
    style LOOP fill:#fff8e8,stroke:#FF9800
    style RETRO fill:#f8e8f8,stroke:#9C27B0
```

---

## Brownfield Process
*Use this when you already have an existing codebase and want to start using this workflow.*

```mermaid
flowchart TD
    A([🏗️ Existing Project]) --> B

    subgraph ONCE ["Run Once Per Project"]
        B["/setup\nScaffold docs/ folder\nCreate AGENTS.md + CLAUDE.md"]
        B --> C["/github-tracking setup\nConnect to GitHub\nCreate status labels"]
    end

    C --> D

    subgraph DISCOVER ["Discovery Phase — understand what already exists"]
        D["/discover\nAI reads your codebase\nInterviews you about the product\nGenerates three docs automatically:"]
        D --> D1["📄 docs/prd.md\nDocuments what the product\ncurrently does"]
        D --> D2["📄 docs/architecture.md\nDocuments the tech stack,\npatterns, and conventions"]
        D --> D3["📄 CLAUDE.md\nCaptures gotchas and rules\nfor future AI sessions"]
    end

    D1 & D2 & D3 --> E

    subgraph PLAN ["Planning Phase — decide what to build next"]
        E["/ux\nWrite UX design specs\nDESIGN.md + EXPERIENCE.md\n(optional — skip for pure backend)"]
        E --> EA["/epics\nBreak new work into Epics and Stories\nBuilds on top of the discovered docs\nCreates GitHub milestones"]
        EA --> ER["/check-readiness\nValidate FR coverage, AC quality\nand architecture alignment"]
    end

    ER --> F

    subgraph LOOP ["Dev Loop — same as greenfield from here"]
        F["/create-story\nSpec out the next story\nReads discovered docs for context\nCreates a GitHub issue"]
        F --> G["/dev-story\nAI implements the story"]
        G --> H["/code-review\nReview + close GitHub issue"]
        H -->|"More stories?"| F
    end

    H --> I

    subgraph POSTMVP ["After MVP — one-off changes"]
        I["/quick-dev\nFor small features or bugfixes\nthat don't need a full story\nAutomatically updates prd.md\nand architecture.md"]
    end

    style ONCE fill:#e8f4f8,stroke:#2196F3
    style DISCOVER fill:#fef9e7,stroke:#F39C12
    style PLAN fill:#e8f8e8,stroke:#4CAF50
    style LOOP fill:#fff8e8,stroke:#FF9800
    style POSTMVP fill:#fdecea,stroke:#E74C3C
```

---

## Migrating from Full BMAD to BMAD-LITE

If you have an existing project using full BMAD (identifiable by a `_bmad/` directory at the project root), use the two-step migration flow rather than starting fresh.

### Step 1 — `/setup migrate`

Non-destructive. Reads `_bmad/config.toml` to find where BMAD stored its artifacts, then moves everything into the BMAD-LITE `docs/` layout:

| BMAD artifact | BMAD-LITE destination |
|---|---|
| `{planning_artifacts}/prd.md` | `docs/prd.md` |
| `{planning_artifacts}/architecture.md` | `docs/architecture.md` |
| `{planning_artifacts}/epics.md` | `docs/epics.md` |
| `{planning_artifacts}/*ux*.md` | `docs/ux/DESIGN.md` / `docs/ux/EXPERIENCE.md` |
| Other planning docs | `docs/project/` |
| `{stories_path}/*.md` | `docs/epics/` |
| `sprint-status.yaml` | Archived to `docs/project/sprint-status-archive.yaml`; status values stamped into each story file's `Status:` frontmatter field (keyed by filename stem) so backfill labels issues correctly |

`AGENTS.md` and `CLAUDE.md` are updated to add any BMAD-LITE sections that are missing; existing content is never replaced.

After the file moves, migrate attempts GitHub label setup and issue backfill inline — if `gh auth` passes, no manual tracking steps are needed. If auth isn't configured, migrate reports what to run manually.

### Step 2 — `/setup clean`

Destructive, but confirms before each target. Run only after verifying migrate succeeded.

Offers to delete three things independently:
- `_bmad/` — BMAD config, scripts, and customization files
- `sprint-status.yaml` — safe to delete since migrate archived a copy
- `src/bmm-skills/` — the original BMAD skill source; BMAD-LITE's `skills/` is the replacement

Each deletion requires explicit `y` confirmation. Tip: review with `git status` before committing the removals.

### Why two steps?

Migrate and clean are intentionally separate so you can verify the layout looks right before removing anything. If the migration output looks wrong, nothing has been deleted yet — you can correct and re-run migrate (it skips files that already exist at the destination).

The full happy-path migration is therefore just two commands:

```
/setup migrate    → moves files, stamps statuses, creates GitHub labels + issues
/setup clean      → removes _bmad/, sprint-status.yaml, src/bmm-skills/ (with confirmation)
```

---

## How the Token Budget Works
*Why this is cheaper than full BMAD — and how the cache makes it even cheaper.*

```mermaid
flowchart LR
    subgraph EXPENSIVE ["⚠️ /create-story — reads everything once per epic"]
        P["docs/prd.md\n(full read)"]
        AR["docs/architecture.md\n(full read)"]
        EP["docs/epics.md\n(full read)"]
        P & AR & EP --> CACHE["📦 docs/epics/epic-N-context.md\nCache: distilled subset\nfor this epic only"]
    end

    subgraph CHEAP ["✅ Subsequent stories in same epic — reads cache only"]
        CACHE --> S2["/create-story\nStory 1.2"]
        CACHE --> S3["/create-story\nStory 1.3"]
        CACHE --> S4["/create-story\nStory 1.4"]
    end

    subgraph DEVSTORY ["✅ /dev-story — reads story file only"]
        S2 & S3 & S4 --> SF["docs/epics/1-N-slug.md\n(story file has everything\nembedded from cache)"]
        SF --> DEV["AI implements\nNo re-reading of\nprd or architecture"]
    end

    style EXPENSIVE fill:#fdecea,stroke:#E74C3C
    style CHEAP fill:#e8f8e8,stroke:#4CAF50
    style DEVSTORY fill:#e8f8e8,stroke:#4CAF50
```

> **The key insight:** You pay the full reading cost once (when creating the first story in an epic).
> Every story after that uses the cache. The `/dev-story` agent only ever reads the story file —
> never the PRD or architecture doc — because `/create-story` embedded everything it needs.

---

## Feeding Project Knowledge Into the PRD and Architecture

Before running `/prd` or `/architecture`, you may already have useful material — a product brief you wrote in Google Docs, competitive research, API vendor documentation, stakeholder meeting notes, prior architectural decisions. This section explains how to get that content in front of Claude.

### Option 1 — Local files in `docs/project/` (recommended)

Create a `docs/project/` folder and drop any upstream inputs there before running `/prd` or `/architecture`. Both skills check this folder automatically on activation and read everything in it.

```
docs/project/
  brief.md              ← product vision, stakeholder requirements
  research.md           ← competitive analysis, user research
  api-vendor-notes.md   ← third-party API docs or constraints
  prior-adr.md          ← architecture decisions already made
  meeting-notes.md      ← anything from planning sessions
```

Any format works — `.md`, `.txt`, even a raw paste saved as a file. Claude reads them all and uses them to pre-populate the PRD brain dump or architecture tech stack discussion. You won't be asked to re-explain what's already there.

**This is also the right place for iterative notes.** If you've been drafting ideas in a separate Claude chat, copy the useful output into a file in `docs/project/` before starting the formal skill run.

### When upstream inputs change mid-project

If you update a file in `docs/project/` after implementation has already started, the flow is:

1. Update the file in `docs/project/`
2. Run `/prd update` — it reads the changed file, updates `docs/prd.md`, then scans `docs/epics/` for any `in-progress` or `done` stories written against the old PRD
3. If affected stories exist, run `/correct-course` — it updates downstream docs and schedules any remediation work as new stories in the right epic

`/correct-course` does **not** re-scan `docs/project/` itself. The trigger is always a known change you've already identified — the `/prd` or `/architecture` update flow surfaces the downstream impact.

### Option 2 — MCP-connected sources (Google Drive, Notion, etc.)

If you have an MCP server connected (Google Drive, Notion, Confluence, etc.), fetch the relevant documents **at the start of the session, before invoking the skill**:

1. Open a new Claude Code session.
2. Ask Claude to fetch the document via MCP: *"Read my product brief from Google Drive at [file name or URL]."*
3. Once Claude confirms it has the content, run `/prd` or `/architecture` in the same session — the fetched content is already in context.

Alternatively, download the file locally and save it to `docs/project/` — then it's persistent across sessions and doesn't require re-fetching each time.

> **Prefer `docs/project/` over re-fetching via MCP each session.** MCP fetches cost tokens every time and require the external service to be available. A local copy in `docs/project/` is free to re-read and works offline.

### Option 3 — Paste directly into the session

For one-off content that doesn't need to persist, paste it into the chat before running the skill:

*"Here's the product brief from our planning doc: [paste]. Now run `/prd`."*

Claude will use it for that session. It won't be available in future sessions unless you save it to `docs/project/`.

### What belongs in `docs/project/` vs `docs/prd.md`

| `docs/project/` | `docs/prd.md` |
|-----------------|---------------|
| Raw inputs — briefs, research, notes, exports | Distilled output — the canonical PRD |
| Written by humans, messy is fine | Written by `/prd`, structured |
| Read once during PRD/arch creation | Read every time the first story of a new epic is created |
| Never auto-generated or overwritten | Updated by `/prd` update flow and `/correct-course` |

Don't put everything into the PRD. Keep raw inputs in `docs/project/` so the PRD stays dense and implementation-focused.

---

## Session Hygiene — Start Fresh Between Phases

Context accumulates silently. If you run `/prd` → `/architecture` → `/epics` → `/create-story` all in one session, the PRD sits in context for every subsequent message — even when only the cache is needed.

**Rule: start a new Claude Code session for each major phase.**

| Phase | What to do |
|-------|-----------|
| After `/prd` is approved | End session. New session for `/architecture`. |
| After `/architecture` is approved | End session. New session for `/epics`. |
| After `/epics` is written | End session. New session for `/create-story`. |
| Each story | One session per story: `/create-story` → `/dev-story` (code-review runs inline at the end). |
| After each story is done | End session before starting the next story. |

**Mid-session:** If a `/dev-story` session is running long, use `/compact` after finishing a major task group (e.g., all backend work done, about to start frontend). This summarizes and compresses prior context without losing your place.

---

## Project File Layout

```
your-project/
├── AGENTS.md              ← AI conventions for all tools (Copilot, Cursor, Claude)
├── CLAUDE.md              ← Claude-specific rules and project conventions
├── docs/
│   ├── project/           ← YOUR UPSTREAM INPUTS (briefs, research, notes, ADRs)
│   ├── prd.md             ← What we're building and why (generated from project/)
│   ├── architecture.md    ← How we're building it (tech stack, patterns)
│   ├── epics.md           ← Epic and story breakdown
│   ├── deferred-items.md  ← Auto-managed deferred findings log
│   ├── security-review-{date}.md ← Security review outputs
│   ├── epics/             ← All per-epic artifacts (stories, cache, retros)
│   │   ├── epic-1-context.md     ← Auto-generated cache (do not edit manually)
│   │   ├── epic-1-retro-{date}.md ← Epic retrospective output
│   │   ├── 1-1-{slug}.md         ← Story spec + implementation record
│   │   ├── 1-2-{slug}.md
│   │   ├── epic-2-context.md
│   │   ├── epic-2-retro-{date}.md
│   │   ├── 2-1-{slug}.md
│   │   └── ...
│   ├── investigations/    ← Case files from /investigate runs
│   ├── specs/             ← Quick-dev specs (post-MVP one-off changes)
│   │   └── {slug}.md
│   ├── ux/                ← UX design specs (from /ux)
│   │   ├── DESIGN.md      ← Visual identity (colors, typography, components)
│   │   ├── EXPERIENCE.md  ← IA, behavior, states, interactions
│   │   ├── mockups/       ← Promoted HTML mockups
│   │   ├── wireframes/    ← Promoted Excalidraw wireframes
│   │   └── .working/      ← In-progress creative artifacts
│   ├── setup/             ← Local dev setup, scripts, resources
│   ├── maintainer/        ← Deployment, runbooks, operational procedures
│   └── sql/               ← Database schema and migrations
```

---

## All Skills

**Project Initialization**
| Invocation | What it does |
|------------|-------------|
| `/setup` | Detects project state and routes automatically: finds `_bmad/` → prompts to run migrate + clean; finds existing `docs/` → idempotent re-run; finds neither → greenfield scaffold of `docs/`, `AGENTS.md`, `CLAUDE.md` |
| `/setup migrate` | Migrate a full-BMAD project to BMAD-LITE — reads `_bmad/config.toml` to locate artifacts, moves planning docs + stories into the BMAD-LITE `docs/` layout, stamps `Status:` into each story file from `sprint-status.yaml`, updates `AGENTS.md` + `CLAUDE.md`, then attempts GitHub label setup + issue backfill inline (gracefully skipped if auth not configured). Non-destructive — never deletes. |
| `/setup clean` | Remove BMAD infrastructure after a successful migrate — confirms before deleting each target: `_bmad/`, `sprint-status.yaml`, and optionally `src/bmm-skills/` |
| `/github-tracking setup` | One-time: GitHub auth + create the four status labels |
| `/github-tracking backfill` | Retroactively create GitHub issues for stories written before tracking was configured |

**Planning**
| Invocation | What it does |
|------------|-------------|
| `/prd` | Auto-detects intent: **create** (no PRD yet), **update** (PRD exists), or **validate** (critique only) |
| `/prd update` | Explicit update — reads `docs/project/` for upstream changes, then checks for in-progress/done stories and recommends `/correct-course` if any are affected |
| `/prd validate` | Critique only — runs the PRD checklist and reports findings without modifying the file |
| `/architecture` | Create or update `docs/architecture.md` — reads `docs/project/` for technical inputs |
| `/ux` | Create, update, or validate UX design specs — produces `docs/ux/DESIGN.md` (visual identity: colors, typography, components) and `docs/ux/EXPERIENCE.md` (IA, behavior, states, interactions, accessibility, key flows). Primary surfaces: **responsive web** and **Apple platforms** (iOS · iPadOS · macOS via SwiftUI). Apple output includes a full HIG compliance checklist, SwiftUI component map, and multi-target layout cascade (iPhone → iPad → Mac). Android deferred as `[FUTURE: Android]`. Renders inline HTML mockups on demand to help visualize color and layout decisions. |
| `/ux update` | Explicit update to existing spines — reads change signal, surfaces conflicts with prior decisions, re-triages HIG checklist items |
| `/ux validate` | Critique only — runs the UX checklist across flow coverage, token completeness, component coverage, state coverage, Apple HIG compliance, and responsive breakpoints |
| `/discover` | Brownfield only: reverse-engineer existing codebase → `prd.md` + `architecture.md` + `CLAUDE.md` |
| `/epics` | Break the PRD into epics and stories, create GitHub milestones |

**Planning Gate**
| Invocation | What it does |
|------------|-------------|
| `/check-readiness` | Validate PRD + architecture + epics are aligned — checks FR coverage, AC testability, story independence, architecture consistency, MVP scope drift, security coverage |

**Dev Flywheel**
| Invocation | What it does |
|------------|-------------|
| `/create-story` | Spec the next `ready-for-dev` story (auto-detected from `docs/epics.md`) |
| `/create-story {epic}-{story}` | Spec a specific story, e.g. `/create-story 2-3` |
| `/create-story refresh-cache` | Force-regenerate the epic context cache even if timestamps look fresh — use after editing `prd.md` or `architecture.md` mid-epic |
| `/dev-story` | Implement the first `ready-for-dev` story found in `docs/epics/` — code-review + security Pass D run inline at the end |
| `/dev-story {path}` | Implement a specific story file, e.g. `/dev-story docs/epics/1-2-user-auth.md` |
| `/code-review` | Standalone review — auto-detects a story in `review` status, or reviews current branch vs main |
| `/code-review {branch}` | Review a specific branch vs main, e.g. `/code-review feature/payments` |
| `/code-review {commit}` | Review a specific commit range, e.g. `/code-review abc123..def456` |
| `/code-review {story-file}` | Review the diff associated with a specific story file |
| `/quick-dev` | Describe a one-off feature or fix — skill scopes it, writes a spec, implements, and updates docs |

**Mid-Sprint Management**
| Invocation | What it does |
|------------|-------------|
| `/investigate` | Start a new investigation — accepts a description, error message, stack trace, ticket ID, or file/module name |
| `/investigate {slug}` | Resume an existing investigation from `docs/investigations/{slug}.md` |
| `/correct-course` | Triggered by a known change — updates docs, schedules remediation stories forward, clears deferred items |
| `/deferred` | Show the full `docs/deferred-items.md` log with status of each scheduled story |

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
| `/retrospective` | Facilitated **epic** retrospective (one per epic, not per sprint) — 5 questions scoped to the target epic's stories, updates `CLAUDE.md`, checks deferred items log, writes `docs/epics/epic-{n}-retro-{date}.md` |
| `/retrospective epic {n}` | Explicit epic target, e.g. `/retrospective epic 2` — skip auto-detection |

---

## Token Spend Reduction vs Original BMAD

Estimates based on a typical project: 3 epics × 4 stories each = 12 stories.

### Per-invocation savings

| Source of waste | Original BMAD | BMAD-LITE | Saved |
|----------------|--------------|-----------|-------|
| Activation ceremony (per skill call) | ~700 tokens | 0 | 700/call |
| Architecture skill (8 JIT step files) | ~4,500 tokens | ~1,200 tokens | 3,300 |
| UX skill (SKILL.md + 3 refs + customize.toml + Sally persona + 5 example assets + creative tools) | ~12,600 tokens | ~4,100 tokens (skill.md + checklist + 2 templates) | ~8,500/run |
| `sprint-status.yaml` read (per dev/review call) | ~300 tokens | 0 | 300/call |
| Agent persona overhead (per skill call) | ~400 tokens | 0 | 400/call |
| `create-story` reading full PRD + arch (per story) | ~4,500 tokens | ~500 tokens (cache hit) | 4,000/story |
| Separate code-review session startup (per story) | ~1,800 tokens | 0 (inline) | 1,800/story |

### Across a 12-story project

| Phase | Original BMAD | BMAD-LITE | Reduction |
|-------|--------------|-----------|-----------|
| Planning (PRD + arch + epics) | ~18,000 | ~8,000 | ~55% |
| `/ux` (1 Create run per project) | ~12,600 | ~4,100 | ~67% |
| `create-story` × 12 | ~58,000 | ~14,000 | ~76% |
| `dev-story` + `code-review` × 12 | ~62,000 | ~42,000 | ~32% |
| Retrospective × 3 epics | ~12,000 | ~4,500 | ~63% |
| **Total** | **~162,600** | **~72,600** | **~55%** |

> These are input token estimates. Output tokens (the AI's actual writing) are roughly the same in both systems — the savings are entirely on the reading/loading side.

### What session hygiene adds on top

Original BMAD typically runs multi-phase sessions, so the PRD and architecture sit in context during `create-story` and `dev-story` even though they're not needed. BMAD-LITE's one-session-per-phase rule eliminates this accumulated context tax — conservatively another **10–20%** reduction on top of the numbers above.

### Bottom line

BMAD-LITE uses roughly **half the tokens** of original BMAD for the same 12-story project — primarily by eliminating the activation ceremony, caching epic context, inlining code review, and enforcing session hygiene. The Claude Pro $15/month plan includes ~1.5M input tokens/month on Sonnet; a 12-story project in BMAD-LITE costs roughly **~70K tokens**, leaving substantial budget for iteration and experimentation.

---

## What Was Cut vs Original BMAD

| Cut | Why |
|-----|-----|
| Activation ceremony (config.yaml, resolve_customization.py, 6-step boot) | Ran on every skill invocation even with zero customizations — pure overhead |
| Three-tier TOML customization surface | Replaced by plain-English rules in `CLAUDE.md` |
| Sprint-status.yaml | Replaced by GitHub issue labels — same visibility, no extra file |
| Subagent spawning | Not available on Claude Pro; replaced with inline passes |
| Step-file JIT architecture (8 files for architecture alone) | Collapsed to single inline workflow |
| Agent personas (bmad-agent-pm, bmad-agent-architect, etc.) | Extra persona tokens on top of skill tokens — not needed for solo use |
| 1,512-line retrospective | Replaced with 5 focused questions |
| PRD decision log + addendum | Captured inline in story Dev Notes instead |
| HTML validation reports | Overkill for personal workflow |
| Pre-PRD analysis phase (brainstorming, PRFAQ, market research) | Out of scope for the build flywheel — use a regular Claude conversation before `/prd` |
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

---

## Relationship to BMAD

This repo tracks upstream BMAD improvements via a separate fork ([BMAD-LITE](https://github.com/rterakedis/BMAD-LITE)). Periodically reviewing `src/bmm-skills/` in that fork against this library surfaces improvements worth porting. Upstream files are never copied directly — BMAD's activation ceremony and customization infrastructure is deliberately absent here.

### Syncing with Upstream BMAD

The BMAD-LITE fork contains a `skills/` directory that is entirely new — it has no equivalent in the upstream repo — so `git merge upstream/main` is safe and will never produce conflicts on any file in `skills/`.

```bash
# Pull upstream changes (safe — only touches src/, docs/, tools/, root README)
git fetch upstream
git merge upstream/main
```

**What syncing gives you:** upstream improvements to the installer, tooling, documentation, and any new BMAD skill concepts worth reviewing.

**What syncing does NOT do automatically:** port upstream skill logic improvements into `skills/`. When upstream improves their version of `create-story`, `code-review`, or similar, those changes land in `src/bmm-skills/` — not in `skills/`. You have to review them manually.

**How to incorporate upstream skill improvements:**

1. Check what changed: `git diff upstream/main..HEAD -- src/bmm-skills/`
2. For each changed skill, read the upstream diff and ask: does this fix a real problem or add genuine value?
3. If yes, port the *idea* into the equivalent file in `skills/` — never copy the upstream file directly. Their files include the activation ceremony, TOML customization hooks, and JIT step-file loading that BMAD-LITE deliberately removed.

**The divergence will grow.** Both repos evolve independently. Upstream may restructure significantly over time. If comparing diffs becomes impractical, treat upstream as an ideas source rather than a merge target — read their changelog and cherry-pick concepts worth porting.

---

## License

MIT — see [LICENSE](LICENSE) for details.
