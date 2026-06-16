## Git Workflow

Use `scripts/commit-push.sh` instead of running individual git commands — one Bash call, zero reasoning overhead:

```bash
# Stage modified tracked files only (default — safest)
bash scripts/commit-push.sh "your commit message"

# Stage specific files
bash scripts/commit-push.sh "your commit message" path/to/file.md another/file.md

# Stage everything including untracked (use with care)
bash scripts/commit-push.sh "your commit message" --all
```

The script stages, commits (with the Co-Authored-By trailer), and pushes to the current branch in one invocation. Do not fall back to the multi-command git workflow in this repo.
