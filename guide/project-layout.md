[← Back to README](../README.md)

## Project File Layout

This is the layout a project ends up with after `/setup` and a few epics' worth of work — not this skills repo itself.

```
your-project/
├── AGENTS.md              ← AI conventions for all tools (Copilot, Cursor, Claude)
├── CLAUDE.md              ← Claude-specific rules and project conventions
├── scripts/
│   └── commit-push.sh     ← one-call commit helper (stage → commit → push); scaffolded by /setup
├── .bmad-lite/
│   └── manifest.json      ← scaffold record (skills_path, surfaces, asset flags); written by /setup and /upgrade-project
├── .claude/
│   ├── settings.json      ← startup hook (add-dir) + guardrail hook wiring
│   └── hooks/             ← zero-token guardrail scripts (installed by /setup)
│       ├── guard-secrets.sh        ← blocks hardcoded secrets at write time
│       ├── guard-design-tokens.sh  ← warns on off-token colors (active when docs/ux/DESIGN.md exists)
│       ├── log-activity.sh         ← streams tool-call events to docs/metrics/activity.jsonl
│       └── README.md
├── docs/
│   ├── project/           ← YOUR UPSTREAM INPUTS (read silently by /prd)
│   │   ├── brief.md             ← from /product-brief — read by /prd Step 1
│   │   ├── brief-addendum.md    ← overflow detail that didn't fit the 1-2 page brief
│   │   ├── forged-idea-{slug}.md ← Hardened output from /forge-idea
│   │   └── research/            ← cited research docs from /research
│   │       └── {type}-{slug}-{date}.md
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
│   │   ├── components-built.md ← Reusable component inventory (auto-maintained by /code-review)
│   │   ├── mockups/       ← Promoted HTML mockups
│   │   ├── wireframes/    ← Promoted Excalidraw wireframes
│   │   └── .working/      ← In-progress creative artifacts
│   ├── setup/             ← Local dev setup, scripts, resources
│   │   ├── swift/         ← Swift/Apple platform guidance (created by /setup for Apple projects)
│   │   │   ├── state-management.md
│   │   │   ├── concurrency.md
│   │   │   ├── architecture.md
│   │   │   ├── ui-composition.md
│   │   │   ├── testing.md
│   │   │   ├── anti-patterns.md
│   │   │   ├── ipados-specific.md   ← present if iPadOS targeted
│   │   │   └── macos-specific.md    ← present if macOS targeted
│   │   └── web/           ← Web/SSG guidance (created by /setup for web projects)
│   │       ├── css-design-system.md
│   │       ├── accessibility-seo.md
│   │       ├── anti-patterns.md
│   │       ├── astro.md             ← present if Astro selected
│   │       └── hugo.md              ← present if Hugo selected
│   ├── evals/             ← Cumulative eval regression net (from /evals and /create-story)
│   │   └── README.md      ← accumulated type:command cases; each story appends enabled cases
│   ├── metrics/           ← Flywheel observability ledger
│   │   ├── README.md
│   │   ├── flywheel-ledger.jsonl   ← one line per /dev-story and /code-review pass (queryable with jq)
│   │   └── activity.jsonl          ← raw tool-call stream from log-activity.sh
│   ├── maintainer/        ← Deployment, runbooks, operational procedures
│   │   ├── swift-audit-{date}.md   ← output of /swift-audit runs
│   │   └── web-audit-{date}.md     ← output of /web-audit runs
│   └── sql/               ← Database schema and migrations
```
