# {project_name}

{project_description}

---

## Docs Structure

Planning and reference docs live in `docs/`. See `AGENTS.md` for the full map.

| Path | Contains |
|------|---------|
| `docs/project/` | Upstream inputs — briefs, research, ADRs, notes (read by `/prd` and `/architecture`) |
| `docs/prd.md` | Product requirements (generated from `docs/project/`) |
| `docs/architecture.md` | Tech stack, patterns, conventions |
| `docs/epics.md` | Epics and story breakdown |
| `docs/setup/` | Local dev setup, scripts, resources |
| `docs/maintainer/` | Operational runbooks |
| `docs/sql/` | Schema, migrations |
| `stories/` | Story files (`{epic}-{story}-{slug}.md`) |
| `specs/` | Quick-dev specs |
| `docs/investigations/` | Investigation case files from `/investigate` |

Skills live in `skills/`. See `skills/README.md` for the full flywheel.

---

## Task Tracking Emoji

Use in all `docs/` files for visual skimming:

| Emoji | Meaning |
|-------|---------|
| 🔳 | Not started |
| 🔁 | In progress |
| ✅ | Done |
| ❌ | Cancelled (add inline reason) |

Story files and specs use `[ ]`/`[x]` checkboxes (GitHub renders these interactively).

---

## Critical Rules

<!-- Add project-specific rules here as they emerge.
     Format: rule on one line, why on the next.
     Example:
     - Always use the `db` helper for queries, never raw SQL strings.
       Reason: prevents injection and ensures connection pooling.
-->

---

## Conventions

<!-- Naming, import style, file organization — patterns every file already follows.
     Populated by /discover (brownfield) or emerges from /retrospective over time.
-->

---

## Known Footguns

<!-- Things that look right but break something.
     Format: what looks right → what actually happens → what to do instead.
-->
