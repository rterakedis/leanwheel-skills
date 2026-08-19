# CLAUDE.md — leanwheel-skills

This repo is a lean, token-efficient port and simplification of the [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) for Claude Code. It ships as a Claude Code plugin (`leanwheel`) via `.claude-plugin/plugin.json`. Skills live in `.claude/skills/` and are registered as `SKILL.md` (uppercase) — the upstream uses `skill.md` (lowercase) and an entirely different file structure (activation ceremony, TOML customization tiers, JIT step files) that this repo deliberately does not carry over.

## Purpose

Maintain a curated, token-conscious set of BMAD skills for use in Claude Code projects. The goal is to periodically check the upstream BMAD Method for new capabilities or fixes worth porting — as *ideas*, never as direct file copies — while preserving the structural simplifications and local enhancements documented in
[`.claude/skills/CLAUDE.md`](.claude/skills/CLAUDE.md). See [guide/comparison.md](guide/comparison.md) for the full cut/added rationale.

---

## Committing and Pushing

Use `scripts/commit-push.sh` instead of running individual git commands — one Bash call, zero reasoning overhead:

```bash
# Stage modified tracked files only (default — safest)
bash scripts/commit-push.sh "your commit message"

# Stage specific files
bash scripts/commit-push.sh "your commit message" path/to/file.md another/file.md

# Stage everything including untracked (use with care)
bash scripts/commit-push.sh "your commit message" --all
```

The script stages, commits (with the Co-Authored-By trailer), and pushes to the current branch in one invocation. Do not fall back to the multi-command git workflow in this repo.

---

## Where the rest lives

These sections moved out of this file so they load only when relevant, instead of in
every session. Content is unchanged — only the location.

- **Upstream sync workflow**, **local customizations by skill**, **harness assets**,
  **web guidance stubs**, and **skills identical to upstream** →
  [`.claude/skills/CLAUDE.md`](.claude/skills/CLAUDE.md), which loads automatically
  whenever you work with a file under `.claude/skills/`. Read it before syncing from
  upstream or editing any skill — it records the deliberate divergences to preserve.
- **Plugin packaging** (manifest layout, marketplace `source`, why there's no `version`)
  → [`.claude-plugin/CLAUDE.md`](.claude-plugin/CLAUDE.md), which loads when you touch
  the plugin or marketplace manifests.

---

## Local Development — symlink consumption (maintainer's machine)

The maintainer does **not** install the marketplace plugin locally — that's a frozen
snapshot for testers. Instead the skills/agents are consumed live via personal-dir
**symlinks** into this repo, so edits propagate to every project on the next session
with no commit/update/restart:

- `~/.claude/skills/<name>` → `…/leanwheel-skills/.claude/skills/<name>`
- `~/.claude/agents/<name>.md` → `…/leanwheel-skills/agents/<name>.md`

This matters because the macOS app does **not** auto-load skills from a project's
`additionalDirectories`; the personal-dir symlinks are what make them load everywhere.

> ⚠️ **REMINDER — after adding a NEW skill or agent, re-run the symlink sync.** Editing
> existing files needs nothing (symlinks are live), but a newly-*added* skill/agent has no
> symlink yet and will silently fail to load in the app (this is exactly how `swift-audit`
> went missing). Re-run:
> ```bash
> for d in /Users/rterakedis/Git-Repos/leanwheel-skills/.claude/skills/*/; do ln -sfn "$d" ~/.claude/skills/"$(basename "$d")"; done
> for a in /Users/rterakedis/Git-Repos/leanwheel-skills/agents/*.md; do ln -sfn "$a" ~/.claude/agents/"$(basename "$a")"; done
> ```
> Then restart the session. (Don't touch `~/.claude/skills/reset-git-staging-branch` — not from this repo.)

---

## Conventions

- Skill files are always named `SKILL.md` (uppercase). Upstream uses `skill.md`.
- No `settings.json` in `.claude/` — this repo is a plugin, not a project config.
- Do not add project-level docs (`docs/`, story files, etc.) — this repo ships skills only.
- When adding a new skill or agent, also re-run the symlink sync (see **Local Development**) so it loads on the maintainer's machine.
- **No project names** in skills, stubs, agents, or scripts. Lessons learned on a real project are recorded generically ("a SwiftUI + Core Data project") in [guide/design-decisions.md](guide/design-decisions.md) as `DD-NN` entries, and skills cite the ID.
- **Trademark rule:** "BMAD"/"BMad" appears only in *references to the upstream project* (credit, comparison, migration, upstream-sync workflow) — never in the name of anything this repo ships (skills, agents, plugin, dirs, scripts, hooks). BMad™, BMad Method™, and BMad Core™ are trademarks of BMad Code, LLC; see LICENSE third-party notices and `license-fix.md`.
