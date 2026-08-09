# leanwheel-skills

A lean, token-efficient set of Claude Code skills for structured AI-assisted software development — designed to fit comfortably within Claude Pro's context budget while keeping the full value of the BMAD planning flywheel.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## What this is

A standalone skills library for [Claude Code](https://claude.ai/code) — a port and simplification of the [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) that separates planning from implementation and keeps each AI session focused on one well-scoped task.

> **New to this?** BMAD is a way of using AI to build software in a structured, repeatable way. You write planning docs first, then AI helps you implement one small piece at a time. Each "skill" is a command you give Claude — like `/spec` to write planning docs or `/dev-story` to write code.

It strips out the activation ceremony and customization overhead of the original BMAD Method while keeping the full planning flywheel (PRD → UX → Architecture → Epics → Stories → Dev → Review), and adds Swift/Apple + web platform guidance systems, autonomous epic/story flywheels with subagent delegation, and a living-documentation loop. See **[guide/features.md](guide/features.md)** for the complete feature list.

---

## Credit

This project is derived from and inspired by **[BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD)** by BMad Code, LLC, used under the [MIT License](https://github.com/bmad-code-org/BMAD-METHOD/blob/main/LICENSE). The BMAD Method is a structured AI development workflow; this project ports its core planning flywheel into a leaner form optimized for Claude Pro's context budget.

The simplicity-ladder / anti-over-engineering layer is adapted — idea, not code — from **[ponytail](https://github.com/DietrichGebert/ponytail)** (MIT-licensed): its 7-rung "laziness ladder," the deletion-focused code-review lens (Pass F), and the deliberate-shortcut marker convention (here spelled `leanwheel:`). As with BMAD, only the concepts were ported; ponytail's intensity dial (lite/full/ultra) and benchmark scoreboard were deliberately left out to keep the layer as plain rules in `CLAUDE.md` rather than added ceremony.

BMad™, BMad Method™, and BMad Core™ are trademarks of BMad Code, LLC (all casings and variations). This project is not affiliated with or endorsed by BMad Code, LLC. See the upstream [trademark guidelines](https://github.com/bmad-code-org/BMAD-METHOD/blob/main/TRADEMARK.md) and this repo's [LICENSE](LICENSE) third-party notices.

---

## Project Quickstart

*Building (or documenting) a product with the full planning flywheel. Just want one task done in some folder, no project? Jump to the [Single-Goal Quickstart](#single-goal-quickstart--any-folder-no-project) below.*

**The short version — you only need to remember three commands:**

| Command | When |
|---|---|
| `/setup` | Once, at the start of a project |
| `/next` | Any time you're unsure what to run — detects project state and routes you to the single next command |
| `/epic-flywheel` | To build — drives a whole epic autonomously with checkpoints |

Everything else is either invoked for you by those three, or `/next` will route you to it at the right moment. The steps below are the full path for reference.

1. **Install the plugin** — skills are then available in every Claude Code session automatically, no `/add-dir` needed:

   ```
   /plugin marketplace add https://github.com/rterakedis/leanwheel-skills
   /plugin install leanwheel@leanwheel
   ```

2. **Scaffold your project** — creates `docs/`, `AGENTS.md`, and `CLAUDE.md`:

   ```
   /setup
   ```

3. **(Optional) Connect GitHub tracking** — one-time auth + status labels:

   ```
   /github-tracking setup
   ```

4. **Decide, then render the planning docs:**

   ```
   /ideate          → work the idea into recorded decisions (brainstorm, pressure-test,
                      resume across sessions — the log lives in docs/project/decisions.md)
   /spec            → render the docs from those decisions: prd (what and why),
                      ux (design specs — skip for pure backend), architecture (stack and patterns)
   /epics           → break the PRD into epics and stories
   /check-readiness → validate everything lines up before coding
   ```

   (The old `/prd`, `/ux`, `/architecture`, `/product-brief`, and `/forge-idea` commands
   still work — they route into `/ideate` and `/spec`.)

5. **Loop through stories until the epic is done:**

   ```
   /create-story   → spec the next story
   /dev-story      → implement it (code review runs inline)
   ```

   Or run the loop hands-off with `/story-flywheel` (per story) or `/epic-flywheel` (a whole epic, with checkpoints).

6. **Wrap the epic:**

   ```
   /harvest-findings {N} → after the manual test pass, capture inline findings,
                           spin in-scope ones into a remediation story, reset the plan
   /retrospective        → capture what worked / what didn't, update CLAUDE.md,
                           condense the closed epic in docs/epics.md
   ```

7. **At a release boundary** (every epic closed, next phase starting) — occasional, and only when you ask for it:

   ```
   /epic-archive cut-release {version} → archive docs/epics.md into
                                         docs/epics/releases/, seed a fresh one
                                         (numbering stays continuous)
   ```

   Then re-plan the new phase from step 4 (`/ideate` if there's real fog, else `/spec` prd update → `/epics` → `/check-readiness`).

Already have an existing codebase instead of starting fresh? Run `/discover` first to reverse-engineer it into `docs/prd.md` + `docs/architecture.md`, then continue from step 3. See **[guide/workflows.md](guide/workflows.md)** for the full greenfield/brownfield flowcharts, and **[guide/skills-reference.md](guide/skills-reference.md)** for every skill and sub-command.

Prefer to clone and symlink the skills locally instead of installing the plugin? See **[guide/installation.md](guide/installation.md)**.

---

## Single-Goal Quickstart — any folder, no project

Not everything is a project. When you just want one task done in some folder — a coworker's repo, a scripts directory, a fresh clone — skip the planning flywheel entirely:

1. **Install the plugin** (step 1 above), once. Skills load in every session, so nothing else to set up.

2. **`cd` into the folder and state the goal:**

   ```
   /dev-single-goal fix the flaky retry logic in sync.sh
   ```

That's the whole quickstart. What the skill does with it:

- **Grills you first** — intent, edge cases, illegal states, invariants — and stops to ask when something material is genuinely ambiguous, instead of guessing.
- **Writes a verifiable plan** for your approval: frozen intent, Always/Ask-First/Never boundaries, file-level tasks, testable acceptance criteria, and the exact verification commands.
- **Implements, then proves it** — the goal isn't "done" until the build and tests actually run green this session (or, with no toolchain, the plan's verification commands do).

Zero footprint: no `docs/` tree is created, nothing is tracked on GitHub, and the plan lives in a self-ignoring `.leanwheel/goals/` folder that never shows up in the host repo's git status. If the work turns out to be the start of something real, the skill offers `/discover` (document an existing codebase) or `/setup` (full lifecycle) at the end — the on-ramp to the [Project Quickstart](#project-quickstart) above. It never scaffolds by default.

---

## Documentation

| Doc | What's in it |
|---|---|
| [guide/features.md](guide/features.md) | Full list of what was removed, kept, and added vs original BMAD |
| [guide/installation.md](guide/installation.md) | Workspace-directory install option, keeping skills up to date |
| [guide/workflows.md](guide/workflows.md) | Greenfield and brownfield process flowcharts |
| [guide/migration.md](guide/migration.md) | Migrating an existing full-BMAD project to Leanwheel |
| [guide/token-budget.md](guide/token-budget.md) | How the epic-context cache works, and measured token savings |
| [guide/project-knowledge.md](guide/project-knowledge.md) | Feeding existing docs/research into the PRD, and session hygiene |
| [guide/project-layout.md](guide/project-layout.md) | Full `docs/` folder layout a scaffolded project ends up with |
| [guide/github-tracking.md](guide/github-tracking.md) | How milestones, issues, and status labels work |
| [guide/deferred-items.md](guide/deferred-items.md) | How deferred findings get logged, scheduled, and re-homed so nothing rots |
| [guide/skills-reference.md](guide/skills-reference.md) | Every skill and sub-command, grouped by phase |
| [guide/comparison.md](guide/comparison.md) | What was cut vs original BMAD, what was added, and how upstream syncing works |

---

## Contributing & Security

See [CONTRIBUTING.md](CONTRIBUTING.md) for the dev workflow and local-customization conventions, [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community standards, and [SECURITY.md](SECURITY.md) to report a vulnerability privately.

---

## License

MIT — see [LICENSE](LICENSE) for details.
