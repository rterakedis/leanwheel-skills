[← Back to README](../README.md)

## GitHub Tracking — Milestones, Issues, and Labels

BMAD-LITE replaces `sprint-status.yaml` with native GitHub primitives. No separate status file to maintain — progress is visible directly in GitHub.

### The model

| GitHub concept | BMAD-LITE meaning |
|---|---|
| **Milestone** | One per epic — title matches the epic title from `docs/epics.md`; GitHub's built-in X/Y closed counter shows epic progress |
| **Issue** | One per story — title is `Story {epic}.{story}: {title}`; body includes the story statement, acceptance criteria, and path to the story file |
| **Label** | Current status of the story — one of five values at any time |

### The five status labels

| Label | Meaning |
|---|---|
| `backlog` | Story exists in `docs/epics.md` but hasn't been spec'ed yet — no story file exists |
| `ready-for-dev` | Story is specced (story file exists) and waiting to be picked up |
| `in-progress` | `/dev-story` has started implementing it |
| `review` | Implementation done, waiting on `/code-review` |
| `done` | Code review passed; issue is closed |

A story isn't `ready-for-dev` just because it's named in the epic breakdown — it earns that label only once `/create-story` actually writes the story file. Labels flow in one direction:

```
epics.md written → [backlog] → create-story completes → [ready-for-dev] → [in-progress] → [review] → [done] + closed
```

### How skills interact with GitHub automatically

| Skill | GitHub action |
|---|---|
| `/epics` | Creates one milestone per epic, then one issue per story labeled `backlog` (no story file yet, so no `github_issue:` write-back at this point) |
| `/create-story` | Transitions the existing `backlog` issue to `ready-for-dev` (or creates one directly at `ready-for-dev` if backfilling), writes the issue number back to the story file's frontmatter (`github_issue: N`) |
| `/dev-story` | Transitions label to `in-progress` when it starts |
| `/dev-story` (DoD pass) | Transitions label to `review` |
| `/code-review` (passes) | Transitions label to `done`, closes the issue |

All GitHub operations are skipped silently if `gh auth` is not configured — they never block the local workflow.

### Setup and backfill

```
/github-tracking setup      → one-time: GitHub auth + create the five labels in your repo
/github-tracking backfill   → retroactively create milestones + issues for stories that predate tracking
```

`/setup migrate` also runs the setup + backfill sequence inline when migrating from full BMAD, as long as `gh auth` is already configured.

### Viewing progress

`/status` reads GitHub milestones and issues to show epic-level progress and per-story label status in one view — no need to open GitHub in a browser.
