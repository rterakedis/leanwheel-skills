# bmad-lite-skills

A lean, token-efficient set of Claude Code skills for structured AI-assisted software development — designed to fit comfortably within Claude Pro's context budget while keeping the full value of the BMAD planning flywheel.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## What this is

This is a standalone skills library for [Claude Code](https://claude.ai/code). It is a port and simplification of the [BMAD Method](https://github.com/bmad-method/bmad) — a structured approach to building software with AI that separates planning from implementation and keeps each AI session focused on one well-scoped task.

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

---

## Project file layout

All output goes under `docs/` in your project. The only root-level files created are `AGENTS.md` and `CLAUDE.md`.

```
your-project/
├── AGENTS.md
├── CLAUDE.md
└── docs/
    ├── prd.md
    ├── architecture.md
    ├── epics.md                       ← epic index
    ├── deferred-items.md
    ├── epics/                         ← all per-epic artifacts
    │   ├── epic-1-context.md          ← auto-generated cache
    │   ├── epic-1-retro-{date}.md     ← epic retrospective
    │   ├── 1-1-{slug}.md              ← story files
    │   └── ...
    ├── specs/                         ← quick-dev specs
    ├── ux/
    │   ├── DESIGN.md
    │   └── EXPERIENCE.md
    ├── investigations/
    ├── project/                       ← your upstream inputs
    ├── setup/
    ├── maintainer/
    └── sql/
```

---

## Keeping skills up to date

```bash
cd ~/repos/bmad-lite-skills
git pull
```

All projects that reference this directory pick up the update immediately — nothing to copy or sync per project.

---

## Relationship to BMAD

This repo tracks upstream BMAD improvements via a separate fork ([BMAD-LITE](https://github.com/rterakedis/BMAD-LITE)). Periodically reviewing `src/bmm-skills/` in that fork against this library surfaces improvements worth porting. Upstream files are never copied directly — BMAD's activation ceremony and customization infrastructure is deliberately absent here.

---

## License

MIT — see [LICENSE](LICENSE) for details.
