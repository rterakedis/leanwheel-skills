#!/usr/bin/env bash
# sabotage.sh — prove a new gate can fail, deterministically and with ~zero model tokens.
#
# A test that has only ever been observed green is unverified. This script performs
# the "revert the fix, keep the test" discriminating check mechanically:
#
#   1. stash the NON-test working-tree changes (the fix), leaving the test files in place
#   2. run the gate command       → must exit NON-zero AND print the named item   (RED)
#   3. restore the stash
#   4. run the gate command again → must exit zero                                (GREEN)
#
# Usage:
#   scripts/sabotage.sh --name <needle> [--test <glob>]... [--base <ref>] -- <gate command...>
#
#   --name <needle>   text that must appear in the RED run's output (the test/case name)
#                     — proves the gate fails *naming the specific item*, not just fails
#   --test <glob>     path glob(s) for the test files to KEEP while the fix is reverted.
#                     Default: any changed path matching *Test*, *test*, *spec*, __tests__,
#                     docs/evals/. Repeatable.
#   --base <ref>      diff base for "changed files" (default: HEAD, i.e. uncommitted work;
#                     use e.g. --base main to sabotage an already-committed story branch —
#                     the fix is reverted with `git checkout <base> -- <files>` and restored
#                     from a stash of the same paths)
#   -- <cmd...>       the gate: e.g. `swift test --filter FooTests` /
#                     `xcodebuild … test -only-testing:App/FooTests` / `pytest -k foo` /
#                     `npm test -- -t foo` / `scripts/evals-run …`
#
# Exit codes / output (last line is machine-readable for the Completion Notes):
#   0  SABOTAGE OK: <name> — red without fix (named), green restored
#   2  GATE CANNOT FAIL: <name> — gate passed with the fix reverted   (the important one)
#   3  GATE RED BUT UNNAMED: <name> not in failure output — the failure isn't discriminating
#   4  GATE NOT GREEN AFTER RESTORE — the tree was left restored; the story is not done
#   5  NOTHING TO REVERT — no non-test changes vs base (sabotage manually: reintroduce
#      the defect / corrupt the input; this script only automates the revert-the-fix mode)
#   1  usage / git error. Restoration is trapped: the tree is put back on any exit.
#
# Why a script: the choice of *what* to break needs judgment only in the
# reintroduce-defect / corrupt-input modes; revert-the-fix is the common case and is
# pure mechanics. Filtered gate command ⇒ two short runs, not two full suites.

set -u
NAME=""; BASE="HEAD"; TESTS=(); CMD=()
while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2;;
    --test) TESTS+=("$2"); shift 2;;
    --base) BASE="$2"; shift 2;;
    --) shift; CMD=("$@"); break;;
    -h|--help) sed -n '2,40p' "$0"; exit 0;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done
[ -z "$NAME" ] || [ ${#CMD[@]} -eq 0 ] && { echo "usage: $0 --name <needle> [--test <glob>] [--base <ref>] -- <gate cmd>" >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo" >&2; exit 1; }

# Changed files vs base (tracked + untracked so a brand-new source file counts as "fix";
# gitignored paths such as build caches are excluded).
CHANGED=()
while IFS= read -r f; do [ -n "$f" ] && CHANGED+=("$f"); done < <( { git diff --name-only "$BASE" --; git ls-files --others --exclude-standard; } | sort -u )
[ ${#CHANGED[@]} -eq 0 ] && { echo "NOTHING TO REVERT — no changes vs $BASE"; exit 5; }

is_test() {
  local f="$1"
  if [ ${#TESTS[@]} -gt 0 ]; then
    for g in ${TESTS[@]+"${TESTS[@]}"}; do case "$f" in $g) return 0;; esac; done; return 1
  fi
  case "$f" in
    *Test*|*test*|*spec*|*Spec*|*__tests__*|docs/evals/*) return 0;;
    *) return 1;;
  esac
}
FIX=(); KEEP=()
for f in "${CHANGED[@]}"; do if is_test "$f"; then KEEP+=("$f"); else FIX+=("$f"); fi; done
[ ${#FIX[@]} -eq 0 ] && { echo "NOTHING TO REVERT — every changed file looks like a test (${CHANGED[*]}). Use --test to narrow, or sabotage manually."; exit 5; }

echo "sabotage: reverting ${#FIX[@]} fix file(s), keeping ${#KEEP[@]} test file(s)"
printf '  revert: %s\n' "${FIX[@]}"

STASH_MSG="sabotage.sh $$ $NAME"
ASIDE="$(git rev-parse --git-dir)/sabotage-aside.$$"
TRACKED=(); UNTRACKED=()
for f in "${FIX[@]}"; do
  if git ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then TRACKED+=("$f"); else UNTRACKED+=("$f"); fi
done
restore() {
  # untracked fix files: moved aside, move back
  if [ -d "$ASIDE" ]; then
    (cd "$ASIDE" && find . -type f) | while IFS= read -r f; do f="${f#./}"; mkdir -p "$(dirname "$f")"; mv -f "$ASIDE/$f" "$f"; done
    rm -rf "$ASIDE"
  fi
  # committed fix (--base): put HEAD's version back
  if [ "$BASE" != "HEAD" ]; then for f in ${TRACKED[@]+"${TRACKED[@]}"}; do git checkout --quiet HEAD -- "$f" 2>/dev/null || true; done; fi
  # tracked uncommitted fix: pop the stash
  if git stash list | grep -qF "$STASH_MSG"; then
    git stash pop --quiet "$(git stash list | grep -F "$STASH_MSG" | head -1 | cut -d: -f1)" >/dev/null 2>&1 \
      || { echo "!! stash pop failed — run: git stash list / git stash pop" >&2; exit 4; }
  fi
}
trap restore EXIT

# Untracked fix files: move aside (stashing untracked paths conflicts on pop when the
# gate run recreates them, e.g. build caches).
for f in ${UNTRACKED[@]+"${UNTRACKED[@]}"}; do mkdir -p "$ASIDE/$(dirname "$f")"; mv "$f" "$ASIDE/$f"; done
# Tracked fix files: stash their uncommitted delta; tests remain in the tree.
if [ ${#TRACKED[@]} -gt 0 ] && ! git diff --quiet HEAD -- "${TRACKED[@]}"; then
  git stash push --quiet -m "$STASH_MSG" -- "${TRACKED[@]}" || { echo "git stash failed" >&2; exit 1; }
fi
if [ "$BASE" != "HEAD" ]; then
  # Committed work: also revert the committed fix (files new since base are removed).
  for f in ${TRACKED[@]+"${TRACKED[@]}"}; do git checkout --quiet "$BASE" -- "$f" 2>/dev/null || rm -f "$f"; done
fi

echo "sabotage: RED run → ${CMD[*]}"
RED_OUT="$("${CMD[@]}" 2>&1)"; RED_RC=$?
restore; trap - EXIT

if [ $RED_RC -eq 0 ]; then
  echo "GATE CANNOT FAIL: $NAME — gate exited 0 with the fix reverted"; exit 2
fi
if ! grep -qF -- "$NAME" <<<"$RED_OUT"; then
  echo "$RED_OUT" | tail -20
  echo "GATE RED BUT UNNAMED: '$NAME' not in failure output (rc=$RED_RC)"; exit 3
fi

echo "sabotage: GREEN run → ${CMD[*]}"
if ! "${CMD[@]}" >/dev/null 2>&1; then
  echo "GATE NOT GREEN AFTER RESTORE: $NAME — tree restored, but the gate fails; fix before closing"; exit 4
fi
echo "SABOTAGE OK: $NAME — red without fix (named), green restored"
