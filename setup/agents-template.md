# AGENTS.md — AI Agent Instructions for {project_name}

> This file applies to all AI agents working in this repository: Claude, Copilot, Cursor, and others.
> It defines where documentation lives, how to write it, and the conventions every agent must follow.
> See `CLAUDE.md` for Claude Code–specific settings.

---

## Docs Structure

All documentation lives in `docs/`. Write to the right folder — never create ad-hoc markdown files at the project root.

| Folder | Purpose | When to write here |
|--------|---------|-------------------|
| `docs/setup/` | Getting the project running | Local dev setup, prerequisites, environment variables, first-run steps |
| `docs/setup/resources.md` | External dependencies | API keys, third-party services, credentials setup, access requests |
| `docs/setup/scripts.md` | Runnable scripts | What each script does, when to use it, expected output |
| `docs/maintainer/` | Keeping it running | Operational procedures, deploy steps, rollback, monitoring |
| `docs/maintainer/runbook.md` | Common operations | Step-by-step procedures for recurring tasks and incident response |
| `docs/sql/` | Database | Schema definitions, how to connect, migration instructions |
| `docs/sql/schema.md` | Table/collection definitions | Fields, types, relationships, indexes, constraints |
| `docs/sql/migrations.md` | Migration history | How to run migrations, rollback steps, migration log |
| `docs/prd.md` | Product requirements | What the product does and why — managed by `/prd` skill |
| `docs/architecture.md` | Technical decisions | Stack, patterns, conventions — managed by `/architecture` skill |
| `docs/epics.md` | Feature roadmap | Epics and stories — managed by `/epics` skill |

**Rules:**
- If a `docs/` subfolder doesn't exist for what you need, ask before creating a new one.
- `index.md` in each folder is the entry point — keep it short and link to detail files.
- Never put setup, maintenance, or schema details in `README.md` — link to `docs/` instead.

---

## Task Tracking Emoji

Use these emoji for task/checklist items in all documentation files. They make status scannable at a glance without opening every item.

| Emoji | Status | When to use |
|-------|--------|-------------|
| 🔳 | Not started | Task exists but no work has begun |
| 🔁 | In Progress | Actively being worked on |
| ✅ | Done | Completed and verified |
| ❌ | Cancelled | Will not be done; include a brief reason inline |

**Usage in docs:**
```markdown
## Setup Checklist
- ✅ Install Node.js 20+
- ✅ Clone the repository
- 🔁 Configure environment variables (see resources.md)
- 🔳 Run database migrations
- 🔳 Seed development data
- ❌ ~~Configure Redis~~ (not needed until v2)
```

**Where this applies:** All files under `docs/`. Story files (`stories/`) and quick-dev specs (`specs/`) use `[ ]`/`[x]` GitHub checkboxes instead — those render as interactive checkboxes in GitHub issues and PRs.

---

## Doc Writing Rules

1. **Lead with the action.** Start every procedure with a verb: "Run", "Open", "Set", "Copy".
2. **One purpose per file.** If a file is doing two things, split it.
3. **Code blocks for every command.** Never write a shell command inline in prose.
4. **State the expected outcome.** After a command or step, say what success looks like.
5. **Link, don't duplicate.** If something is documented elsewhere, link to it — don't copy it.
6. **Date-stamp significant changes.** Add `<!-- updated: YYYY-MM-DD -->` when updating a procedure that others depend on.

---

## What NOT to Put in Docs

- **Secrets or credentials** — use a secrets manager or `.env.example` with placeholders
- **Generated content** — don't document what can be read from the code directly
- **Speculative future plans** — that belongs in `docs/prd.md` or GitHub issues
