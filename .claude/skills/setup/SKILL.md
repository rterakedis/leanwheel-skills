---
name: setup
description: Scaffold the docs folder structure, create AGENTS.md and CLAUDE.md. Also handles migrating existing full-BMAD projects to Leanwheel. Use when starting a new project or when the user says "setup project", "init docs", "migrate", or "setup migrate/clean".
---

# Setup Skill

**Goal:** Scaffold `docs/`, `AGENTS.md`, `CLAUDE.md` for shared conventions across sessions. Also detects and migrates existing BMAD infrastructure.

**Idempotent:** Safe to re-run. Creates missing, never overwrites.

## Activation — Detect Mode

Run detection before anything else:

```bash
# Check for full BMAD infrastructure
ls _bmad/ 2>/dev/null && echo "bmad" || echo "none"
```

Also check for explicit invocation: `/setup migrate` or `/setup clean`.

**Route based on detection:**

| Condition | Route |
|---|---|
| User invoked `/setup migrate` | Jump to **Migrate Flow** |
| User invoked `/setup clean` | Jump to **Clean Flow** |
| `_bmad/` exists | Report: "Found full BMAD infrastructure. Run `/setup migrate` to move artifacts to Leanwheel layout, then `/setup clean` to remove BMAD files." Stop. |
| `_bmad/` absent, `docs/` exists | Idempotent re-run — proceed to **Scaffold Flow**, skip existing |
| `_bmad/` absent, `docs/` absent | Greenfield — ask project name, proceed to **Scaffold Flow** |

---

## Scaffold Flow

Ask these questions (can be combined into one prompt):
1. "Project name + one-sentence description?" (store as {project_name}, {project_description})
2. "Where is your leanwheel-skills directory?" (store as {skills_path}, e.g. `~/repos/leanwheel-skills`). If already present in `.claude/settings.json`, skip this question.
3. "Which Apple platform(s) is this app targeting? (select all that apply: iOS / iPadOS / macOS / none)" (store as {platforms} — a list; set {is_apple_platform} = true if any Apple platform selected)
4. "Does this project ship a web surface? (none / web app / Astro / Hugo / other SSG)" (store as {web_surface}; set {is_web} = true if not none)

### Step 1 — Scaffold Docs

Create folders + index files (skip if exist):
```
docs/
  project/          ← briefs, research, ADRs (read by /prd, /architecture)
  epics/            ← stories, context cache, retros
  specs/            ← quick-dev specs
  setup/            ← index.md, resources.md, scripts.md
  maintainer/       ← index.md, runbook.md
  sql/              ← index.md, schema.md, migrations.md
  evals/            ← README.md (the cumulative regression net — see /evals)
  metrics/          ← README.md (flywheel observability ledger)
```

Populate from `stubs/`. Use {project_name} + today's date in frontmatter. Copy `stubs/evals/README.md` → `docs/evals/README.md` and `stubs/metrics/README.md` → `docs/metrics/README.md` (skip if they exist).

### Step 2 — Write AGENTS.md

Write to root using template. If exists, append missing sections (never replace).

### Step 3 — Write or Update CLAUDE.md

If not exists: create from template.
If exists: check for `## Docs Structure` + `## Task Tracking Emoji`. Add missing sections at top (after project desc). Don't modify existing.

### Step 3a — Append Apple Platform Guardrails (conditional)

If {is_apple_platform} is yes:
- Check whether `## Swift/SwiftUI Guardrails` already exists in CLAUDE.md. If it does, skip (never duplicate).
- Otherwise, append the full contents of `{skills_path}/.claude/skills/setup/stubs/modern-swiftui.md` to CLAUDE.md, preceded by a `---` separator.

### Step 3b — Scaffold Swift Reference Docs (conditional)

If {is_apple_platform} is true:
- Create `docs/setup/swift/` if it does not exist.
- Copy the following **shared** files from `{skills_path}/.claude/skills/setup/stubs/swift/` into `docs/setup/swift/`. Skip any file that already exists (never overwrite):
  - `state-management.md`
  - `concurrency.md`
  - `architecture.md`
  - `ui-composition.md`
  - `testing.md`
  - `anti-patterns.md`
- If {platforms} includes **iPadOS**: also copy `ipados-specific.md`.
- If {platforms} includes **macOS**: also copy `macos-specific.md`.

### Step 3c — Append Web Guardrails (conditional)

If {is_web} is true:
- Check whether `## Web Guardrails` already exists in CLAUDE.md. If it does, skip (never duplicate).
- Otherwise, append the full contents of `{skills_path}/.claude/skills/setup/stubs/modern-web.md` to CLAUDE.md, preceded by a `---` separator.

### Step 3d — Scaffold Web Reference Docs (conditional)

If {is_web} is true:
- Create `docs/setup/web/` if it does not exist.
- Copy the following **shared** files from `{skills_path}/.claude/skills/setup/stubs/web/` into `docs/setup/web/`. Skip any file that already exists (never overwrite):
  - `css-design-system.md`
  - `accessibility-seo.md`
  - `anti-patterns.md`
- If {web_surface} is **Astro**: also copy `astro.md`.
- If {web_surface} is **Hugo**: also copy `hugo.md`.
- If {web_surface} is **other SSG** or **web app**: shared files only; note that framework-specific guidance can be added via `/refresh-web`.

### Step 3e — Scaffold deterministic guardrail hooks

Copy the **zero-token** guardrail hook scripts from `{skills_path}/.claude/skills/setup/stubs/hooks/` into the project's `.claude/hooks/` (create the dir; skip any file that already exists, never overwrite):
- `guard-secrets.sh` — blocks hardcoded secrets at write/commit time (the one mandatory enforcement hook)
- `guard-design-tokens.sh` — advisory off-token color warning (active only when `docs/ux/DESIGN.md` exists)
- `log-activity.sh` — appends the raw tool-call stream to `docs/metrics/activity.jsonl`
- `README.md` — hook reference

Make the `.sh` files executable (`chmod +x .claude/hooks/*.sh`). These pair with the agentic guardrails: secret prevention moves from "the model remembers" to "the harness enforces."

> **Subagents need no scaffolding.** The flywheel's `lw-story-creator` / `lw-story-developer` / `lw-story-reviewer` agents ship with the `leanwheel` plugin and are available wherever it's installed. Nothing to copy per-project.

### Step 3f — Scaffold project scripts

Copy these from `{skills_path}/scripts/` into the project's `scripts/` (create `scripts/` if absent; skip any that already exist), then `chmod +x` them:
- `commit-push.sh` — one-call stage/commit/push with the Co-Authored-By trailer.
- `gh-track.sh` — deterministic GitHub issue status transitions (used by github-tracking + the flywheels; keeps label moves byte-identical and zero-token).

Then append the git workflow instruction block to CLAUDE.md: check whether `## Git Workflow` already exists in CLAUDE.md. If it does, skip (never duplicate). Otherwise, append a `---` separator followed by the full contents of `{skills_path}/.claude/skills/setup/stubs/commit-workflow.md`.

### Step 4 — Wire up settings.json (skills dir + guardrail hooks)

Create or update `.claude/settings.json` (create `.claude/` if absent). Merge — never clobber existing keys.

1. **Skills auto-load** — add the startup hook for the skills directory if not already present:
   ```json
   { "hooks": { "startup": ["add-dir {skills_path}"] } }
   ```
   If a `startup` entry already points at a skills directory, skip.

2. **Guardrail hooks** — merge the `PreToolUse` / `PostToolUse` blocks from `{skills_path}/.claude/skills/setup/stubs/hooks/hooks-settings.json` into `.claude/settings.json`. Append to the existing `hooks` arrays (don't replace `startup` or any user-added hooks). If a leanwheel guard hook command is already wired, skip it (idempotent).

### Step 5 — Write manifest + Done

Write `.leanwheel/manifest.json` (create `.leanwheel/` if absent) recording what was scaffolded, so `/upgrade-project` can sync precisely later:

```json
{
  "skills_path": "{skills_path}",
  "scaffolded_at": "{today}",
  "surfaces": { "apple": {is_apple_platform}, "platforms": {platforms}, "web": {is_web}, "web_surface": "{web_surface}" },
  "assets": { "hooks": true, "evals": true, "metrics": true, "agents": "plugin-level", "commit_script": true }
}
```

If the file exists, update its fields (don't discard unknown keys).

Report created/skipped lists. Note the skills path wired into the startup hook, the guardrail hooks installed, and that the eval set + metrics ledger are ready.

Next:
  Greenfield → `/product-brief` (idea not formed) or `/prd` (idea formed)
  Brownfield → `/discover`
  Fill `docs/setup/index.md` with dev instructions
  Unsure at any point from here on → `/next` routes to the single next command

---

## Migrate Flow (`/setup migrate`)

Move full-BMAD artifacts into Leanwheel layout. **Non-destructive** — only moves/copies, never deletes. Run `/setup clean` afterward to remove BMAD files.

### Step 1 — Read BMAD config

Read `_bmad/config.toml` (and `_bmad/config.user.toml` if present) to resolve:
- `planning_artifacts` path (default: `docs/`) — where prd.md, architecture.md, epics.md live
- `implementation_artifacts` path (default: `docs/`) — where sprint-status.yaml lives
- `stories_path` — where story files live (default: `docs/stories/` or `stories/`)

If config is unreadable or keys are missing, use defaults and note assumptions.

### Step 2 — Inventory

Scan and report what was found:

```bash
find {planning_artifacts} -name "prd.md" -o -name "architecture.md" -o -name "epics.md" -o -name "*ux*.md"
find {stories_path} -name "*.md" | sort
ls {implementation_artifacts}/sprint-status.yaml 2>/dev/null
```

Show the inventory. Ask: "Ready to migrate? (y/n)"

### Step 3 — Move planning docs

For each file, move to Leanwheel canonical path if not already there. Skip if destination exists (never overwrite).

| Source (BMAD) | Destination (Leanwheel) |
|---|---|
| `{planning_artifacts}/prd.md` | `docs/prd.md` |
| `{planning_artifacts}/architecture.md` | `docs/architecture.md` |
| `{planning_artifacts}/epics.md` | `docs/epics.md` |
| `{planning_artifacts}/*ux*.md` | `docs/ux/DESIGN.md` or `docs/ux/EXPERIENCE.md` (ask user which if ambiguous) |
| Any other `{planning_artifacts}/*.md` | `docs/project/{filename}` |

### Step 4 — Move story files

Move each story file from `{stories_path}` to `docs/epics/`. Story filenames are preserved (`{epic}-{story}-{slug}.md`).

```bash
for f in {stories_path}/*.md; do
  mv "$f" docs/epics/$(basename "$f")
done
```

Skip any file that would collide. Report moved + skipped.

### Step 5 — Handle sprint-status.yaml

BMAD stores story status centrally in `sprint-status.yaml`, not in individual story files. Leanwheel story files carry their own `Status:` frontmatter field, which is what `/github-tracking backfill` reads to set GitHub labels. Without this step, every migrated story would appear as `ready-for-dev` regardless of its actual state.

**5a — Archive:**
Copy `sprint-status.yaml` to `docs/project/sprint-status-archive.yaml`. Do not delete the original (that's `/setup clean`'s job).

**5b — Stamp story files:**
For each story file moved to `docs/epics/` in Step 4, derive the sprint-status.yaml key by stripping the `.md` extension from the filename (e.g., `1-1-user-authentication.md` → key `1-1-user-authentication`). Look up that key under `development_status` in `sprint-status.yaml`. Map the BMAD status to the Leanwheel `Status:` value:

| sprint-status.yaml value | Story file `Status:` |
|---|---|
| `backlog` | `ready-for-dev` |
| `ready-for-dev` | `ready-for-dev` |
| `in-progress` | `in-progress` |
| `review` | `review` |
| `done` | `done` |

If the story file already has a `Status:` line, skip it (never overwrite). If the key is not found in `sprint-status.yaml`, default to `ready-for-dev` and add it to the warning list. If `sprint-status.yaml` was not present at all, default all stories to `ready-for-dev` and warn once.

Add the `Status:` line to the story file's frontmatter block (between the `---` delimiters) if missing. Report: stamped (with resolved status), defaulted (key not found), and skipped (already had Status).

### Step 6 — Update AGENTS.md + CLAUDE.md

Run **Scaffold Flow** Step 2 + Step 3 to add any Leanwheel sections missing from existing files. Never replace existing content.

### Step 7 — Attempt GitHub tracking setup

Check GitHub auth silently:

```bash
gh auth status 2>/dev/null && gh repo view --json nameWithOwner 2>/dev/null
```

**If both pass:** Proceed inline — execute **SETUP** (create the four status labels) then **BACKFILL** (preview story list, ask user to confirm, create milestones + issues). This is the happy path; no manual steps needed for GitHub tracking.

**If either fails:** Report which check failed. Tell the user: "GitHub auth not configured or no remote set. After running `/setup clean`, run `/github-tracking setup` then `/github-tracking backfill`."

### Step 8 — Done

Report:
- Planning docs moved (source → destination)
- Stories stamped with Status (stamped / defaulted / skipped)
- Files skipped due to collision
- Any story keys not found in sprint-status.yaml (defaulted to `ready-for-dev`)
- GitHub tracking: completed inline, or steps needed with reason

Next: Run `/setup clean` to remove BMAD infrastructure.

---

## Clean Flow (`/setup clean`)

Remove BMAD infrastructure after a successful migration. **Destructive and irreversible** — confirm before each target.

Prerequisite check: warn if migrate has not been run (i.e., `docs/prd.md` does not exist) and ask user to confirm they want to proceed anyway.

### Target 1 — `_bmad/`

> "Delete `_bmad/` (BMAD config, scripts, and customization files)? This cannot be undone. (y/n)"

If yes: `rm -rf _bmad/`

### Target 2 — `sprint-status.yaml`

> "Delete `{implementation_artifacts}/sprint-status.yaml`? An archive copy was saved to `docs/project/sprint-status-archive.yaml` during migrate. (y/n)"

If yes: delete the file. If archive copy does not exist, warn before deleting.

### Target 3 — BMAD skills source (`src/bmm-skills/`)

> "Delete `src/bmm-skills/` (the original BMAD skill source files)? Leanwheel skills in `skills/` are the replacement. (y/n)"

If yes: `rm -rf src/bmm-skills/`

Offer each target independently — user can delete some and skip others.

### Done

Report deleted targets. Suggest: run `git status` to review before committing.
