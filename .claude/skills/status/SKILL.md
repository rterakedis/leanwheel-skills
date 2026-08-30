---
name: status
description: Show current epic and story progress and the next command to run. Use when the user says "status", "sprint status", or "show progress".
---

# Status Skill

**Goal:** Show epic/story progress and name the single next command.

## Run the script (DD-69)

```bash
bash scripts/status.sh
```

That is the whole happy path. The script renders the dashboard, the overall count, and a
`NEXT` line from each story's frontmatter `status:` — the machine-readable source of truth
(DD-51). It needs no `gh`, no auth, and no network, so it works offline and in a fresh clone.

Do **not** re-derive the counts in-model when the script is present: the rendering is
deterministic, and doing it by hand is the turn of latency and tokens this script exists to
remove (same split as `gh-track.sh`/DD-62 — script owns the mechanics, this skill owns the
judgment).

Other modes, when asked for specifically:

| Mode | Use |
|---|---|
| `scripts/status.sh --line` | One line; what the status line renders. Rarely needed here. |
| `scripts/status.sh --json` | Machine-readable, for another skill to consume. |
| `scripts/status.sh --drift` | Compare frontmatter against GitHub labels/state. The only mode that hits the network. |

Run `--drift` when the user asks whether GitHub is in sync, or when a tracking bug is
suspected. Any drift it reports is fixed by `/github-tracking sync`, not by hand.

## If the script is absent

An older project scaffolded before DD-69 has no `scripts/status.sh`. Say so once, recommend
`/upgrade-project`, and fall back to the in-model path for this run:

Check auth (`gh auth status`, `gh repo view`). If that fails, show the story `status:` fields
from `docs/epics/` directly.

1. Fetch milestones: `gh api repos/.../milestones --jq 'sort_by(.number) | ...'`. If none: "Run `/create-story`."
2. Fetch all issues: `gh issue list --state all --limit 200 --json number,title,labels,milestone,state --jq 'sort_by(...)'`
3. Render: group by milestone (epic). Issues with no milestone under "⚠ Untracked".

```
PROJECT STATUS  {repo}  {date}
Epic {N}: {title}  [{closed}/{total} done]
  #{issue}  {icon} {label}  {epic}.{story}: {title}
OVERALL  {closed}/{total} stories done
```

Icons: 📋 ready-for-dev | 🔄 in-progress | 👀 review | ✅ done | 🔲 not created (in epics.md, no issue).

For 🔲: read `docs/epics.md` for stories without a story file.

## Next action

The script already prints `NEXT`. Relay it, and add routing it can't decide:

- Any `review` → `/code-review` on {N.M}
- Any `in-progress` → `/dev-story` continue {N.M}
- Any `ready-for-dev` → `/dev-story` start {N.M}
- 🔲 planned → `/create-story` spec {N.M}
- All done → `/retrospective`

For routing beyond the dev loop (planning gaps, epic boundaries, post-MVP), suggest `/next`.

## Always-on alternative

If the user is asking for status often, the status line renders the same state on every
message for zero tokens. Offer it once:

```json
{ "statusLine": { "type": "command", "command": "./scripts/status.sh --line", "padding": 0 } }
```

in `.claude/settings.json` (`/setup` and `/upgrade-project` wire this automatically).
