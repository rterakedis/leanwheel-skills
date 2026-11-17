#!/usr/bin/env bash
# Builds the run's workspace from the `reviewapp` fixture (evals/fixtures/reviewapp) as a git repo:
#   1. commit the base state, tag it `review-base`
#   2. apply the "story's" changes: a TRACKED modification (src/catalog.py) plus an UNTRACKED
#      new file (src/pagination.py) that holds the planted bug. Nothing is committed after the tag.
# Fixed author/committer/dates keep it deterministic. Runs only with `claude plugin eval --scaffold`.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fixtures/reviewapp" && pwd)"
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
export GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" GIT_COMMITTER_DATE="2026-01-01T00:00:00Z"

cp -R "$src/." .
overlay="$(mktemp -d)"
mv story-changes "$overlay/"   # keep the overlay out of the workspace and the base commit

git init -q -b main
git config commit.gpgsign false
git add -A
git commit -q -m "base: catalog skeleton and story 1.1"
git tag review-base

cp -R "$overlay/story-changes/." .
rm -rf "$overlay"
# Result: src/catalog.py modified (tracked); src/pagination.py new (untracked, never `git add`ed).
