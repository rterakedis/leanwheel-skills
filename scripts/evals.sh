#!/usr/bin/env bash
# evals.sh — run the project's command eval set with zero model tokens.
#
# The eval set (docs/evals/epic-*.md, e2e-*.md) is a cumulative regression net: every
# `type: command` case is a shell command plus an expected result. Executing them needs
# no model — only *collecting* them did, and that read grew with the project (see the
# evals skill → RUN). This script owns collection, batching, assertion and reporting, so
# RUN is a single call whose cost does not grow with the case count.
#
# It is also the CI seam. leanwheel ships no pipeline config because the CI is unknown —
# GitHub Actions, Jenkins, GitLab, a pre-push hook. This script is the contract instead:
# it exits 0 when the net is green and 1 on any regression, so whatever runs CI just
# calls it.
#
# Usage:
#   scripts/evals.sh [--epic <n>] [--file <path>]... [--dir <path>] [--case <id>]
#                    [--list] [--quiet]
#
#   --epic <n>     scope to docs/evals/epic-<n>.md (repeatable)
#   --file <path>  scope to an explicit eval file (repeatable; skips discovery)
#   --dir <path>   eval set directory (default: docs/evals)
#   --case <id>    run only cases whose id matches this prefix (e.g. 3.2 or 3.2-1)
#   --list         collect and print the cases, run nothing (parser dry-run)
#   --quiet        suppress per-case PASS lines; failures and the summary still print
#
# Assertions (`expect:`):
#   exit-0                      command must exit 0
#   output-contains:"<needle>"  combined stdout+stderr must contain <needle>
#   output-matches:/<ere>/      combined output must match the ERE
#
# Empty output fails a contains/matches case even on exit 0 — a gate that enumerates
# must assert it enumerated, and a walk that printed nothing cannot discriminate.
#
# `type: judge` cases are counted and reported as skipped. Judging needs a model; that
# stays in the evals skill, invoked with /evals --judge.
#
# Exit codes:
#   0  every enabled command case passed
#   1  one or more regressions (or a case whose `expect:` could not be parsed)
#   2  usage error, or no eval files found
#
# Last line is the machine-readable report the evals skill's RUN contract specifies:
#   RUN <scope>: <p>/<t> command pass, <j> judge skipped. Regressions: <list or none>

set -uo pipefail

DIR="docs/evals"
EPICS=(); FILES=(); CASE_FILTER=""; LIST_ONLY=0; QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --epic)  EPICS+=("$2"); shift 2;;
    --file)  FILES+=("$2"); shift 2;;
    --dir)   DIR="$2"; shift 2;;
    --case)  CASE_FILTER="$2"; shift 2;;
    --list)  LIST_ONLY=1; shift;;
    --quiet) QUIET=1; shift;;
    -h|--help) sed -n '2,45p' "$0"; exit 0;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

# ---- resolve scope -----------------------------------------------------------------
if [ ${#FILES[@]} -eq 0 ]; then
  if [ ${#EPICS[@]} -gt 0 ]; then
    for n in "${EPICS[@]}"; do
      f="$DIR/epic-$n.md"
      [ -f "$f" ] && FILES+=("$f") || echo "warn: $f not found" >&2
    done
    SCOPE="epic $(IFS=,; echo "${EPICS[*]}")"
  else
    # Everything except README.md — the README carries the format example, whose
    # placeholder headers would otherwise parse as cases.
    while IFS= read -r f; do FILES+=("$f"); done < <(
      find "$DIR" -maxdepth 1 -name '*.md' ! -name 'README.md' 2>/dev/null | sort
    )
    SCOPE="all"
  fi
fi
[ ${#FILES[@]} -eq 0 ] && { echo "no eval files found under $DIR" >&2; exit 2; }

# ---- collect cases -----------------------------------------------------------------
# One row per case, US-separated (\037): id | file | type | enabled | run | expect
# A tab separator would be wrong here: tab is IFS whitespace, so `read` collapses
# consecutive tabs and an empty `run:` would silently shift `expect` into its place.
# Robust to cases written inside ``` fences or bare: fences are ignored and only the
# `### EVAL` header plus its field lines are read. Trailing #-comments are stripped
# from the enum-valued fields only (type/enabled) — never from run/expect, where a
# `#` may be part of the command or the needle.
TSV="$(mktemp)"; OUT="$(mktemp)"
trap 'rm -f "$TSV" "$OUT"' EXIT

awk '
  function flush() {
    if (id != "" && id !~ /[{}]/)
      printf "%s\037%s\037%s\037%s\037%s\037%s\n", id, FILENAME, type, enabled, run, expect
    id=""; type=""; enabled=""; run=""; expect=""
  }
  function val(line) { sub(/^[a-z]+:[ \t]*/, "", line); return line }
  function enumval(line,   v) { v = val(line); sub(/[ \t]+#.*$/, "", v); return v }
  /^```/ { next }
  /^### +EVAL +/ {
    flush()
    id = $0; sub(/^### +EVAL +/, "", id); sub(/[ \t]+[—-].*$/, "", id)
    type="command"; enabled=""; next
  }
  /^### / { flush(); next }
  id == "" { next }
  /^type:/    { type    = enumval($0); next }
  /^enabled:/ { enabled = enumval($0); next }
  /^run:/     { run     = val($0); next }
  /^expect:/  { expect  = val($0); next }
  END { flush() }
' "${FILES[@]}" > "$TSV"

TOTAL=0; PASSED=0; JUDGE=0; DISABLED=0
REGRESSIONS=""

# ---- list mode ---------------------------------------------------------------------
if [ "$LIST_ONLY" -eq 1 ]; then
  while IFS=$'\037' read -r id file type enabled run expect; do
    [ -n "$CASE_FILTER" ] && case "$id" in "$CASE_FILTER"*) ;; *) continue;; esac
    printf '%-14s %-8s enabled=%-6s %s\n' "$id" "$type" "${enabled:-?}" "${run:-(no run:)}"
  done < "$TSV"
  echo "-- $(wc -l < "$TSV" | tr -d ' ') case(s) parsed from ${#FILES[@]} file(s)"
  exit 0
fi

# ---- assertion ---------------------------------------------------------------------
# check_expect <expect> <exit_code> <output_file> -> prints reason on failure, returns 1
check_expect() {
  local expect="$1" code="$2" out="$3" needle re
  case "$expect" in
    exit-0)
      [ "$code" -eq 0 ] && return 0
      echo "exit $code, expected 0"; return 1;;
    output-contains:*)
      needle="${expect#output-contains:}"
      needle="${needle%\"}"; needle="${needle#\"}"
      if [ ! -s "$out" ]; then echo "empty output — gate cannot discriminate"; return 1; fi
      grep -qF -- "$needle" "$out" && return 0
      echo "output does not contain \"$needle\" (exit $code)"; return 1;;
    output-matches:*)
      re="${expect#output-matches:}"
      re="${re%/}"; re="${re#/}"
      if [ ! -s "$out" ]; then echo "empty output — gate cannot discriminate"; return 1; fi
      grep -qE -- "$re" "$out" && return 0
      echo "output does not match /$re/ (exit $code)"; return 1;;
    "")
      echo "no expect: field"; return 1;;
    *)
      echo "unparseable expect: $expect"; return 1;;
  esac
}

# ---- run, batching identical commands ----------------------------------------------
# Each distinct `run:` executes ONCE and scores every case sharing it. On Apple projects
# a per-case invocation would mean one Simulator launch per case, which exhausts it.
while IFS= read -r cmd; do
  [ -z "$cmd" ] && continue

  # Does any in-scope, enabled command case use this command?
  want=0
  while IFS=$'\037' read -r id file type enabled run expect; do
    [ "$type" = "command" ] || continue
    [ "$enabled" = "true" ] || continue
    [ "$run" = "$cmd" ] || continue
    [ -n "$CASE_FILTER" ] && case "$id" in "$CASE_FILTER"*) ;; *) continue;; esac
    want=1; break
  done < "$TSV"
  [ "$want" -eq 1 ] || continue

  [ "$QUIET" -eq 1 ] || echo "-- run: $cmd"
  bash -c "$cmd" > "$OUT" 2>&1
  code=$?

  while IFS=$'\037' read -r id file type enabled run expect; do
    [ "$type" = "command" ] || continue
    [ "$enabled" = "true" ] || continue
    [ "$run" = "$cmd" ] || continue
    [ -n "$CASE_FILTER" ] && case "$id" in "$CASE_FILTER"*) ;; *) continue;; esac
    TOTAL=$((TOTAL + 1))
    if reason="$(check_expect "$expect" "$code" "$OUT")"; then
      PASSED=$((PASSED + 1))
      [ "$QUIET" -eq 1 ] || echo "   PASS $id"
    else
      echo "   FAIL $id — $reason"
      REGRESSIONS="${REGRESSIONS:+$REGRESSIONS, }$id"
    fi
  done < "$TSV"
done < <(cut -d "$(printf '\037')" -f5 "$TSV" | sort -u)

# ---- tally the cases that never ran -------------------------------------------------
while IFS=$'\037' read -r id file type enabled run expect; do
  [ -n "$CASE_FILTER" ] && case "$id" in "$CASE_FILTER"*) ;; *) continue;; esac
  if [ "$type" = "judge" ]; then
    [ "$enabled" = "true" ] && JUDGE=$((JUDGE + 1))
  elif [ "$enabled" != "true" ]; then
    DISABLED=$((DISABLED + 1))
  elif [ -z "$run" ]; then
    # enabled command case with no command: counted as a failure, not silently skipped
    TOTAL=$((TOTAL + 1))
    echo "   FAIL $id — enabled command case has no run: field"
    REGRESSIONS="${REGRESSIONS:+$REGRESSIONS, }$id"
  fi
done < "$TSV"

[ "$DISABLED" -gt 0 ] && [ "$QUIET" -eq 0 ] && echo "-- $DISABLED disabled case(s) skipped"

echo "RUN $SCOPE: $PASSED/$TOTAL command pass, $JUDGE judge skipped. Regressions: ${REGRESSIONS:-none}"
[ -z "$REGRESSIONS" ] && exit 0
exit 1
