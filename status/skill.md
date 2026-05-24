---
name: status
description: Show current epic and story progress via GitHub milestones and issues. Use when the user says "status", "sprint status", or "show progress".
---

# Status Skill

**Goal:** Show epic/story progress via GitHub.

Activation: Check auth (`gh auth status`, `gh repo view`). If fails: show story Status fields from `docs/epics/`.

1. Fetch milestones: `gh api repos/.../milestones --jq 'sort_by(.number) | ...'`. If none: "Run `/create-story`."
2. Fetch all issues: `gh issue list --state all --limit 200 --json number,title,labels,milestone,state --jq 'sort_by(...)'`
3. Render dashboard: group by milestone (epic). Issues with no milestone under "⚠ Untracked".

Format:
```
PROJECT STATUS  {repo}  {date}
Epic {N}: {title}  [{closed}/{total} done]
  #{issue}  {icon} {label}  {epic}.{story}: {title}
OVERALL  {closed}/{total} stories done
```

Icons: 📋 ready-for-dev | 🔄 in-progress | 👀 review | ✅ done | 🔲 not created (in epics.md, no issue).

For 🔲: read `docs/epics.md` for stories without GitHub issue.

4. Next action:
   - Any `review` → `/code-review` on {N.M}
   - Any `in-progress` → `/dev-story` continue {N.M}
   - Any `ready-for-dev` → `/dev-story` start {N.M}
   - 🔲 exists → `/create-story` spec {N.M}
   - All done → `/retrospective`
