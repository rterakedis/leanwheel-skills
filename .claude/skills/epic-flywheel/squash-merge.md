# Epic Flywheel — Step 5b: Squash-merge to main (Apple / manual-test epics, conditional)

Read at the epic boundary only when the manual test pass needs a build the user drives (`apple_project = true`, or any epic whose test plan must be built/run outside the agent — e.g. Xcode/TestFlight, a native desktop app). Skip for web/library epics where the agent runs the tests itself.

1. Check the project's `CLAUDE.md` for a merge-at-boundary rule (look for an "Epic-boundary merge" rule).
2. **No such rule** → do NOT merge. Leave the branch open and only offer the PR in the boundary report.
3. **Rule present** → do it now, after gates 1–4c are green and the test plan (step 5) is written: squash-merge the epic branch to `main`, then remove the worktree (rationale: DD-25).

```bash
gh pr create --fill --base main --head feature/<epic-slug>
gh pr merge --squash --delete-branch                       # run from the PRIMARY tree, not the worktree
git -C <primary> worktree remove <worktree-path>; git -C <primary> pull --ff-only origin main
```

Note: `gh pr merge` may fail its local checkout step if run from inside the worktree — the remote merge still lands; finish the worktree-remove + `pull` from the primary tree.

Then continue with the boundary report (step 6).
