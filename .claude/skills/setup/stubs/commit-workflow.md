## Git Workflow

<!-- leanwheel:git-workflow v2 — MANAGED BLOCK. /upgrade-project replaces everything up to the closing marker; put project-specific git rules outside it. -->

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

**Squash-merge repos: one branch per PR.** After a PR is squash-merged, start the next change on a fresh branch off `origin/main` (`git fetch && git switch -c <new> origin/main`). Don't keep committing on the merged branch, and don't just rebase it. Its original commits and the squash commit on `main` touch the same lines with unrelated history, so every later PR from that branch conflicts.

**Shell checks on macOS.** zsh does not word-split unquoted variables, so `git diff -- $files` with a newline-separated list passes one bogus pathspec and reports "no difference" without any error. macOS `/bin/bash` is 3.2, which has no `mapfile`. When correctness depends on splitting, run the script under `bash` explicitly, split into an array with `IFS=$'\n' read -r -d '' -a arr <<<"$list"` (or a `while read` loop), and include a known-positive control: a file you *know* differs has to show up before you trust a clean result.

<!-- /leanwheel:git-workflow v2 -->
