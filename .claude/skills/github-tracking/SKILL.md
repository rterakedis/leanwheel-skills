---
name: github-tracking
description: Composable GitHub issue/milestone tracking operations. Called by other skills — not invoked directly by the user.
---

# GitHub Tracking (Composable)

Reference library of tracking operations called by other skills at marked points.

Directly invocable: `/github-tracking setup` (one-time) | `/github-tracking backfill` (retroactive) | `/github-tracking sync` (reconcile labels/state).

## Prerequisites Check

Before composable ops (ENSURE-MILESTONE, CREATE-ISSUE, TRANSITION, CLOSE-ISSUE):
- `gh auth status` + `gh repo view --json nameWithOwner`
- Both pass: proceed. Either fails in composable call: skip silently, warn once.
- Either fails in SETUP/BACKFILL: handle auth inline.

---

## SETUP (one-time)

1. Check auth: `gh auth status`. If no, run `gh auth login` (interactive).
2. Verify auth succeeded: `gh auth status`.
3. Verify repo: `gh repo view --json nameWithOwner`. Fail if no remote.
4. Create labels: `backlog`, `ready-for-dev`, `in-progress`, `review`, `done` with `--force`.
5. Report: auth user, repo. Next: `/backfill` or `/create-story`.

---

## BACKFILL (retroactive)

Retroactively create milestones/issues for stories with `github_issue: 0` (safe to re-run).

1. Verify auth (gh auth status, repo view).
2. Scan docs/epics/: `grep -rl "^github_issue: 0"` + files with no `github_issue:` line.
3. Preview list + confirm: "Create milestones + issues + write numbers back?"
4. For each story: read epic/story/title/Status, add `github_issue: 0` if missing, ENSURE-MILESTONE, label by Status, CREATE-ISSUE, CLOSE-ISSUE if done. Report per-story.
5. Summary: {N} issues, {M} milestones, {K} closed. Next: `/status`.

---

## SYNC (reconcile labels and state)

Reconcile GitHub issue labels and open/closed state against the current `status:` field in every story file. Safe to re-run — idempotent.

### Status → label/state mapping

| story `status:` | Expected GitHub label | Issue state |
|---|---|---|
| `draft` / `ready` | `ready-for-dev` | open |
| `in-progress` | `in-progress` | open |
| `review` | `review` | open |
| `done` / `complete` | `done` | closed |
| `cancelled` | `done` | closed |

### Steps

1. Verify auth (`gh auth status`, `gh repo view --json nameWithOwner`). Fail fast if either fails.
2. Build diff table: for each story file in `docs/stories/` that has a non-zero `github_issue:`:
   - Read `status:` and `github_issue:` from frontmatter.
   - Fetch current GitHub label(s) and state: `gh issue view {N} --json state,labels`
   - Determine expected label from the mapping above.
   - If current label set doesn't include expected label OR current state doesn't match: add to diff list.
3. Print diff table (story file | issue # | current label | expected label | current state | expected state). If no diffs: report "All issues in sync." and stop.
4. Confirm: "Apply {N} changes?"
5. For each diff:
   - TRANSITION to expected label (remove old status label, add new).
   - If expected state is `closed` and issue is open: CLOSE-ISSUE.
   - If expected state is `open` and issue is closed: reopen with `gh issue reopen {N}`.
   - Report per-issue: "#N → label:done + closed ✓"
6. Summary: {N} issues updated, {M} already in sync.

---

## ENSURE-MILESTONE

Find or create milestone for epic. Input: `epic_num`, `epic_title` from epics.md.
- Check if exists: `gh api repos/.../milestones --jq "... select(.title | startswith(...))"`
- If exists: use title. If not: create with POST, description from epics.md.
- Return: milestone_title.

---

## CREATE-ISSUE

Create issue for story. Input: `story_file` (optional), `epic_num`, `story_num`, `story_title`, `milestone_title`, AC summary, `initial_label` (default: `ready-for-dev`).
- Build body from story (statement + ACs + repo path).
- `gh issue create --title "Story {epic}.{num}: {title}" --body --milestone --label "{initial_label}"`
- Extract issue number from URL.
- If `story_file` provided: write back `sed -i '' "s/^github_issue: 0$/github_issue: {N}/" "{file}"`
- If no `story_file` (source is epics.md): skip write-back; issue number will be recorded when `/create-story` generates the story file.
- Report: "Created #N → URL"

---

## TRANSITION

Move issue to new status by swapping label. Input: `story_file`, `new_label` (in-progress/review/done).
- Read issue number from frontmatter: `grep "^github_issue:" | awk`
- If 0/empty: skip + warn.
- Get current label: `gh issue view {N} --json labels --jq '... select(.name | test(...))'`
- Edit: `gh issue edit {N} --remove-label {old} --add-label {new}`

## CLOSE-ISSUE

Close issue when done. Input: `story_file`.
- Read issue number (same as TRANSITION).
- `gh issue close {N} --comment "Story complete..."`
```

Also run TRANSITION with `new_label: done` to apply the done label before closing (closed issues retain their labels for milestone progress tracking).

---

## Status Label Flow

```
epics.md written → [backlog]
                      ↓ create-story completes
                   [ready-for-dev]
                      ↓ dev-story starts
                   [in-progress]
                      ↓ dev-story DoD passes
                   [review]
                      ↓ code-review passes
                   [done] + issue closed
```

Milestone progress in GitHub UI automatically shows X/Y closed issues.
