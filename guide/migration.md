[← Back to README](../README.md)

## Migrating from Full BMAD to Leanwheel

If you have an existing project using full BMAD (identifiable by a `_bmad/` directory at the project root), use the two-step migration flow rather than starting fresh.

### Step 1 — `/setup migrate`

Non-destructive. Reads `_bmad/config.toml` to find where BMAD stored its artifacts, then moves everything into the Leanwheel `docs/` layout:

| BMAD artifact | Leanwheel destination |
|---|---|
| `{planning_artifacts}/prd.md` | `docs/prd.md` |
| `{planning_artifacts}/architecture.md` | `docs/architecture.md` |
| `{planning_artifacts}/epics.md` | `docs/epics.md` |
| `{planning_artifacts}/*ux*.md` | `docs/ux/DESIGN.md` / `docs/ux/EXPERIENCE.md` |
| Other planning docs | `docs/project/` |
| `{stories_path}/*.md` | `docs/epics/` |
| `sprint-status.yaml` | Archived to `docs/project/sprint-status-archive.yaml`; status values stamped into each story file's `Status:` frontmatter field (keyed by filename stem) so backfill labels issues correctly |

`AGENTS.md` and `CLAUDE.md` are updated to add any Leanwheel sections that are missing; existing content is never replaced.

After the file moves, migrate attempts GitHub label setup and issue backfill inline — if `gh auth` passes, no manual tracking steps are needed. If auth isn't configured, migrate reports what to run manually.

### Step 2 — `/setup clean`

Destructive, but confirms before each target. Run only after verifying migrate succeeded.

Offers to delete three things independently:
- `_bmad/` — BMAD config, scripts, and customization files
- `sprint-status.yaml` — safe to delete since migrate archived a copy
- `src/bmm-skills/` — the original BMAD skill source; Leanwheel's `skills/` is the replacement

Each deletion requires explicit `y` confirmation. Tip: review with `git status` before committing the removals.

### Why two steps?

Migrate and clean are intentionally separate so you can verify the layout looks right before removing anything. If the migration output looks wrong, nothing has been deleted yet — you can correct and re-run migrate (it skips files that already exist at the destination).

The full happy-path migration is therefore just two commands:

```
/setup migrate    → moves files, stamps statuses, creates GitHub labels + issues
/setup clean      → removes _bmad/, sprint-status.yaml, src/bmm-skills/ (with confirmation)
```
