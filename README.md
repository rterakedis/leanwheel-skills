# bmad-lite-skills

A lean, token-efficient set of Claude Code skills for structured AI-assisted software development — designed to fit comfortably within Claude Pro's context budget while keeping the full value of the BMAD planning flywheel.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## What this is

A standalone skills library for [Claude Code](https://claude.ai/code) — a port and simplification of the [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) that separates planning from implementation and keeps each AI session focused on one well-scoped task.

> **New to this?** BMAD is a way of using AI to build software in a structured, repeatable way. You write planning docs first, then AI helps you implement one small piece at a time. Each "skill" is a command you give Claude — like `/prd` to write requirements or `/dev-story` to write code.

It strips out the activation ceremony and customization overhead of the original BMAD Method while keeping the full planning flywheel (PRD → UX → Architecture → Epics → Stories → Dev → Review), and adds Swift/Apple + web platform guidance systems, autonomous epic/story flywheels with subagent delegation, and a living-documentation loop. See **[guide/features.md](guide/features.md)** for the complete feature list.

---

## Credit

This project is derived from and inspired by **[BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD)** by BMad Code, LLC, used under the [MIT License](https://github.com/bmad-code-org/BMAD-METHOD/blob/main/LICENSE). The BMAD Method is a structured AI development workflow; this project ports its core planning flywheel into a leaner form optimized for Claude Pro's context budget.

BMad™ and BMad Method™ are trademarks of BMad Code, LLC. This project is not affiliated with or endorsed by BMad Code, LLC.

---

## Quickstart

1. **Install the plugin** — skills are then available in every Claude Code session automatically, no `/add-dir` needed:

   ```
   /plugin marketplace add https://github.com/rterakedis/bmad-lite-skills
   /plugin install bmad-lite@bmad-lite
   ```

2. **Scaffold your project** — creates `docs/`, `AGENTS.md`, and `CLAUDE.md`:

   ```
   /setup
   ```

3. **(Optional) Connect GitHub tracking** — one-time auth + status labels:

   ```
   /github-tracking setup
   ```

4. **Write the planning docs, in order:**

   ```
   /prd            → what you're building and why
   /ux             → design specs (skip for pure backend)
   /architecture   → tech stack and patterns
   /epics          → break the PRD into epics and stories
   /check-readiness → validate everything lines up before coding
   ```

5. **Loop through stories until the epic is done:**

   ```
   /create-story   → spec the next story
   /dev-story      → implement it (code review runs inline)
   ```

   Or run the loop hands-off with `/story-flywheel` (per story) or `/epic-flywheel` (a whole epic, with checkpoints).

6. **Wrap the epic:**

   ```
   /retrospective  → capture what worked / what didn't, update CLAUDE.md
   ```

Already have an existing codebase instead of starting fresh? Run `/discover` first to reverse-engineer it into `docs/prd.md` + `docs/architecture.md`, then continue from step 3. See **[guide/workflows.md](guide/workflows.md)** for the full greenfield/brownfield flowcharts, and **[guide/skills-reference.md](guide/skills-reference.md)** for every skill and sub-command.

Prefer to clone and symlink the skills locally instead of installing the plugin? See **[guide/installation.md](guide/installation.md)**.

---

## Documentation

| Doc | What's in it |
|---|---|
| [guide/features.md](guide/features.md) | Full list of what was removed, kept, and added vs original BMAD |
| [guide/installation.md](guide/installation.md) | Workspace-directory install option, keeping skills up to date |
| [guide/workflows.md](guide/workflows.md) | Greenfield and brownfield process flowcharts |
| [guide/migration.md](guide/migration.md) | Migrating an existing full-BMAD project to BMAD-LITE |
| [guide/token-budget.md](guide/token-budget.md) | How the epic-context cache works, and measured token savings |
| [guide/project-knowledge.md](guide/project-knowledge.md) | Feeding existing docs/research into the PRD, and session hygiene |
| [guide/project-layout.md](guide/project-layout.md) | Full `docs/` folder layout a scaffolded project ends up with |
| [guide/github-tracking.md](guide/github-tracking.md) | How milestones, issues, and status labels work |
| [guide/skills-reference.md](guide/skills-reference.md) | Every skill and sub-command, grouped by phase |
| [guide/comparison.md](guide/comparison.md) | What was cut vs original BMAD, what was added, and how upstream syncing works |

---

## Contributing & Security

See [CONTRIBUTING.md](CONTRIBUTING.md) for the dev workflow and local-customization conventions, [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community standards, and [SECURITY.md](SECURITY.md) to report a vulnerability privately.

---

## License

MIT — see [LICENSE](LICENSE) for details.
