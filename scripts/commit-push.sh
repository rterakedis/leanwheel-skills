#!/usr/bin/env bash
# Usage: commit-push.sh "commit message" [file ...] [--all]
#   file ...  explicit paths to stage (preferred — avoids accidental secrets)
#   --all     stage all tracked+untracked changes (git add -A); use with care
#   (no paths)  stage only modified tracked files (git add -u)
#
# Appends the standard Co-Authored-By trailer automatically.

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 \"commit message\" [file ...] [--all]" >&2
  exit 1
fi

MSG="$1"; shift

ADD_ALL=false
FILES=()
for arg in "$@"; do
  if [[ "$arg" == "--all" ]]; then
    ADD_ALL=true
  else
    FILES+=("$arg")
  fi
done

# Stage files
if [[ ${#FILES[@]} -gt 0 ]]; then
  git add -- "${FILES[@]}"
elif $ADD_ALL; then
  git add -A
else
  git add -u
fi

# Nothing to commit?
if git diff --cached --quiet; then
  echo "Nothing staged to commit." >&2
  exit 0
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)

git commit -m "$(printf '%s\n\nCo-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>' "$MSG")"
git push origin "$BRANCH"

echo "Pushed to $BRANCH."
