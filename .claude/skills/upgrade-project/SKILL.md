---
name: upgrade-project
description: Bring an existing bmad-lite project up to the latest skills/stubs/hooks/framework. Detection-based — works even on projects scaffolded before this skill existed. Use when the user says "upgrade project", "sync bmad", "update scaffolding", or after pulling new bmad-lite-skills changes.
---

# Upgrade Project Skill

**Goal:** Reconcile a project that was scaffolded by an older `bmad-lite-skills`
against the current version — add new assets (hooks, agents wiring, evals, metrics),
refresh stubs that the project hasn't locally edited, and append any new guardrail/
doc sections — **without ever clobbering the user's own edits.**

**Idempotent + non-destructive.** Adds and refreshes; never deletes project content.
Always previews a plan and waits for confirmation before applying.

**Relationship to `/setup`:** `/setup` is first-run scaffolding. `/upgrade-project`
is the recurring sync. Existing projects have no manifest — this skill detects state
by **presence and content**, then writes a manifest going forward.

---

## Step 1 — Locate the skills source

Resolve `{skills_path}`:
1. `.bmad-lite/manifest.json` → `skills_path` if present.
2. Else the `add-dir` target in `.claude/settings.json` startup hook.
3. Else ask the user (e.g. `~/repos/bmad-lite-skills`).

Confirm `{skills_path}/.claude/skills/setup/stubs/` exists. If not, stop — wrong path.

## Step 2 — Detect surfaces

Determine what this project uses (so we only sync relevant assets):
- `is_apple` = `docs/setup/swift/` exists OR `.xcodeproj`/`.xcworkspace`/`Package.swift` present
- `is_web` = `docs/setup/web/` exists OR `package.json` with a web framework present
- `has_ux` = `docs/ux/DESIGN.md` exists

## Step 3 — Build the upgrade plan (preview, don't apply yet)

Scan for gaps. For each item, classify as **ADD** (missing), **REFRESH** (stub
unchanged from an older bmad version — safe to update), **CONFLICT** (file exists and
was locally edited — skip, flag for manual review), or **OK** (already current).

Check these:

| Area | Detection |
|---|---|
| Guardrail hooks | `.claude/hooks/{guard-secrets,guard-design-tokens,log-activity}.sh` present + executable |
| Hook wiring | `.claude/settings.json` `hooks.PreToolUse/PostToolUse` reference the bmad guard scripts |
| Eval set | `docs/evals/README.md` present |
| Metrics ledger | `docs/metrics/README.md` present |
| Swift stubs | each `docs/setup/swift/*.md` vs `{skills_path}/.../stubs/swift/*.md` (only if `is_apple`) |
| Web stubs | each `docs/setup/web/*.md` vs stubs (only if `is_web`) |
| Swift guardrails block | `## Swift/SwiftUI Guardrails` in CLAUDE.md (only if `is_apple`) |
| Web guardrails block | `## Web Guardrails` in CLAUDE.md (only if `is_web`) |
| Commit script | `scripts/commit-push.sh` present + executable; `## Git Workflow` in CLAUDE.md |
| Docs structure | `## Docs Structure`, `## Task Tracking Emoji` in CLAUDE.md |

**REFRESH vs CONFLICT for stubs** — the safe-overwrite test:
- Compare the project file against **every** historical version of that stub the
  source repo has (use git history of `{skills_path}` if available:
  `git -C {skills_path} log --oneline -- .claude/skills/setup/stubs/<f>`). If the
  project file's content hashes to any committed version of the stub, the user never
  edited it → **REFRESH** (copy the current stub over it).
- If it matches none, the user edited it → **CONFLICT**: do not overwrite. Report it
  with a one-line diff summary so the user can merge manually (or run the relevant
  `/refresh-swift` / `/refresh-web` to reconcile).
- If git history isn't available, fall back to: identical to current stub → OK;
  differs → CONFLICT (never auto-overwrite a differing stub without provenance).

Present the plan as a table: `ADD / REFRESH / CONFLICT / OK` per item. Summarize:
"Will add N, refresh M, skip K conflicts (need manual merge). Proceed? (y/n)"

## Step 4 — Apply (after confirmation)

In dependency order, applying only ADD and REFRESH items:

1. **Dirs:** create `docs/evals/`, `docs/metrics/` if missing; copy their `README.md`
   from `stubs/evals/` and `stubs/metrics/` (skip if present).
2. **Hooks:** copy missing `stubs/hooks/*.sh` + `README.md` into `.claude/hooks/`;
   `chmod +x` them. Never overwrite an existing hook script unless it's an unedited
   REFRESH (same git-provenance test as stubs).
3. **Hook wiring:** merge the `hooks-settings.json` PreToolUse/PostToolUse blocks into
   `.claude/settings.json` if the bmad guard commands aren't already wired. Preserve
   `startup` and any user hooks.
4. **Stubs (REFRESH only):** copy current swift/web stubs over unedited project copies.
   Leave CONFLICTs untouched.
5. **Commit script:** if `scripts/commit-push.sh` is missing, copy from
   `{skills_path}/scripts/commit-push.sh` and `chmod +x`. If `## Git Workflow` is
   missing from CLAUDE.md, append `---` + `stubs/commit-workflow.md`.
6. **CLAUDE.md sections:** append any missing guardrail/structure blocks (same logic as
   `/setup` Steps 3/3a/3c) — check-heading-then-append, never modify existing prose.
6. **Manifest:** write/update `.bmad-lite/manifest.json` with the current
   `scaffolded_at` date, surfaces, and asset flags.

## Step 5 — Report

Print:
- **Added:** new assets installed (hooks, evals/metrics dirs, etc.)
- **Refreshed:** stubs updated from source (with the from→to if a version is known)
- **Conflicts (manual):** locally-edited files left untouched — tell the user to merge
  by hand or run `/refresh-swift` / `/refresh-web` to reconcile guidance.
- **Already current:** count only.
- Next steps: if hooks were newly added, note they take effect on the next session
  (Claude Code loads `settings.json` hooks at startup); suggest a quick
  `/status` or a trial `/story-flywheel` run to confirm subagents resolve.

## Notes

- **Token-safe:** this skill reads small files and runs `git log`/hash comparisons —
  no model-heavy work. Run it whenever you pull new bmad-lite-skills changes.
- It never touches `docs/epics/` story files, `docs/prd.md`, `docs/architecture.md`,
  or any planning content — only framework scaffolding.
- The CONFLICT path is deliberately conservative: a locally-tuned stub is a feature,
  not drift. We surface it; we never silently overwrite it.
