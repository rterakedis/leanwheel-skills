[← Back to README](../README.md)

## Installation

There are two ways to use these skills: **plugin install** (recommended for new setups, see the [README quickstart](../README.md#quickstart)) or **clone + symlink** (manual, useful if you want to track `main` directly instead of going through plugin marketplace updates).

### Option B — Clone + symlink

> **Why symlinks and not `/add-dir`?** An earlier version of this doc recommended cloning the repo and adding it as a workspace directory with `/add-dir`, optionally automated via a `.claude/settings.json` startup hook. That approach is unreliable in practice — the Claude Code app does not reliably auto-load skills from a session's `additionalDirectories`. Symlinking into your personal `~/.claude/` directory is what actually makes skills and agents load in every session.

#### 1 — Clone once

```bash
git clone https://github.com/rterakedis/bmad-lite-skills ~/repos/bmad-lite-skills
```

Put it wherever you keep shared tools. The path doesn't matter as long as it's consistent.

#### 2 — Symlink skills and agents into your personal Claude directory

```bash
for d in ~/repos/bmad-lite-skills/.claude/skills/*/; do
  ln -sfn "$d" ~/.claude/skills/"$(basename "$d")"
done

for a in ~/repos/bmad-lite-skills/agents/*.md; do
  ln -sfn "$a" ~/.claude/agents/"$(basename "$a")"
done
```

#### 3 — Restart your Claude Code session

Skills and agents now load automatically in every project — no `/add-dir`, no settings.json hook needed. Edits to a symlinked file (e.g. from a `git pull`) are picked up live since the symlink points at the same file; only a **newly added** skill or agent needs the loop above re-run, plus a session restart.

## Keeping skills up to date

```bash
cd ~/repos/bmad-lite-skills
git pull
```

Existing symlinks point at the live files, so every project picks up the update on its next session start — nothing to copy or sync per project. If a new skill or agent was added upstream, re-run the symlink loop from step 2 above.

If you installed via the plugin marketplace instead, run `/plugin marketplace update` to pick up new commits.
