# Contributing to leanwheel-skills

This repo ships as a Claude Code plugin (`leanwheel`). Skills live in `.claude/skills/<name>/SKILL.md`, flywheel subagents live in `agents/`, and scaffolding stubs live under `.claude/skills/setup/stubs/`. See [CLAUDE.md](CLAUDE.md) for the full architecture, local-customization notes, and packaging details before making changes.

## Ground rules

- **Skill files are always `SKILL.md` (uppercase).** Upstream Leanwheel uses lowercase `skill.md` — this is an intentional, permanent divergence. Don't "fix" the casing.
- **Agents live in `agents/` at the repo root**, not `.claude/agents/`. The plugin manifest only registers agents from the root-level directory.
- This repo ships skills only — don't add project-level docs (`docs/`, story files, `.claude/settings.json`, etc.) to the repo itself. Those belong in projects that *consume* this plugin.
- Keep changes scoped to one skill/agent/stub at a time where possible — makes review and upstream-sync diffing easier.

## Setting up a local dev loop

The maintainer doesn't install this as a packaged plugin locally — skills and agents are consumed live via symlinks so edits show up immediately, no commit/restart needed:

```bash
for d in .claude/skills/*/; do ln -sfn "$(pwd)/$d" ~/.claude/skills/"$(basename "$d")"; done
for a in agents/*.md; do ln -sfn "$(pwd)/$a" ~/.claude/agents/"$(basename "$a")"; done
```

If you add a **new** skill or agent (not just edit an existing one), re-run the loop above and restart your Claude Code session — new files need a fresh symlink, existing ones update live.

## Making a change

1. Edit the relevant `SKILL.md`, stub, or agent file.
2. If you're editing a skill with a known upstream counterpart, check the **Local Customizations by Skill** section in [CLAUDE.md](CLAUDE.md) first — many skills carry intentional divergence from Leanwheel that should be preserved, not reverted.
3. Test the change against a real (or scratch) leanwheel project: invoke the skill via its slash command and confirm the behavior matches what you intended.
4. If you touched packaging (`plugin.json`, `marketplace.json`), run `claude plugin validate ./` — it should pass with only the "no version" warning.

## Pulling upstream changes

See the **Upstream Sync Workflow** section in [CLAUDE.md](CLAUDE.md). In short: diff the upstream skill against the local one, and merge rather than overwrite if local customizations exist.

## Submitting a PR

- Keep the PR description focused on *why*, not just *what* — especially for skill behavior changes, since the reasoning is what future maintainers (and future-you) need.
- Don't include unrelated formatting or reflow changes in the same PR as a behavioral change.
- If your change affects a skill documented under **Local Customizations by Skill** in CLAUDE.md, update that section to describe the new behavior.

## Reporting bugs vs. security issues

- Behavioral bugs, unclear skill prompts, or feature requests: open a regular GitHub issue.
- Security-relevant issues (unsafe shell execution, a guardrail hook that can be bypassed, a committed secret): see [SECURITY.md](SECURITY.md) instead — do not open a public issue.
