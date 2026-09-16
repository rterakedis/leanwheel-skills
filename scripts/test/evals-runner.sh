#!/usr/bin/env bash
# evals-runner.sh — self-test for scripts/evals.sh. Zero model tokens.
#
# evals.sh is the only sanctioned way to RUN a project's regression net, and five skills
# depend on its report line and exit code (DD-71). This test pins its behavior against
# committed fixtures so an edit to the parser cannot silently weaken a gate.
#
# It asserts *which* cases passed and failed and *why*, not just the exit code: an exit 1
# on the negative fixture would still be satisfied if only one of its six failure modes
# worked, which is exactly the vacuous gate this runner exists to prevent.
#
# Usage:  bash scripts/test/evals-runner.sh        (from the repo root or anywhere)
# Exit:   0 all checks pass · 1 any check failed

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
RUNNER="$HERE/../evals.sh"
FIX="$HERE/fixtures/evals-runner"
PASS=0; FAIL=0

check() {  # check <description> <command...> — passes when the command exits 0
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then PASS=$((PASS + 1)); echo "ok     $desc"
  else FAIL=$((FAIL + 1)); echo "NOT OK $desc"; fi
}
has()     { printf '%s\n' "$1" | grep -qF -- "$2"; }
lacks()   { ! printf '%s\n' "$1" | grep -qF -- "$2"; }
last_is() { [ "$(printf '%s\n' "$1" | tail -1)" = "$2" ]; }
eq()      { [ "$1" = "$2" ]; }

run_in() {  # run_in <dir> <args...> — sets OUT and CODE
  OUT="$(cd "$1" && shift && bash "$RUNNER" "$@" 2>&1)"; CODE=$?
}

# ---- green: everything that should pass does, for the right reasons ----------------
run_in "$FIX/green"
check "green: exits 0"                          eq "$CODE" 0
check "green: report line is exact" \
  last_is "$OUT" "RUN all: 6/6 command pass, 1 judge skipped. Regressions: none"
check "green: batching — 6 cases scored by 5 invocations" \
  eq "$(printf '%s\n' "$OUT" | grep -c '^-- run: ')" 5
check "green: README format example never parsed"   lacks "$OUT" "should-never-run"
check "green: disabled case skipped, not run"       has "$OUT" "1 disabled case(s) skipped"
check "green: fenced case parsed"                   has "$OUT" "PASS e2e.checkout-1"
check "green: trailing comment stripped from type:" has "$OUT" "PASS 1.1-1"
check "green: '#' inside a needle kept verbatim"    has "$OUT" "PASS 1.2-3"

run_in "$FIX/green" --list
check "list: runs nothing"                          lacks "$OUT" "PASS"
check "list: 8 cases from 2 files (README excluded)" \
  has "$OUT" "8 case(s) parsed from 2 file(s)"

run_in "$FIX/green" --epic 1 --case 1.1 --quiet
check "scope: --epic + --case narrows to 2 cases" \
  last_is "$OUT" "RUN epic 1: 2/2 command pass, 0 judge skipped. Regressions: none"
check "scope: --quiet suppresses PASS lines"        lacks "$OUT" "PASS"

# ---- negative: every failure mode fails, each named, each for its own reason --------
run_in "$FIX/neg"
check "neg: exits 1"                                eq "$CODE" 1
check "neg: 0 of 6 pass"                            has "$OUT" "RUN all: 0/6 command pass"
check "neg: red exit code"          has "$OUT" "FAIL 9.1-1 — exit 1, expected 0"
check "neg: absent needle"          has "$OUT" "FAIL 9.1-2 — output does not contain"
check "neg: empty output never passes vacuously" \
  has "$OUT" "FAIL 9.1-3 — empty output — gate cannot discriminate"
check "neg: regex miss"             has "$OUT" "FAIL 9.1-4 — output does not match"
check "neg: unparseable expect"     has "$OUT" "FAIL 9.1-5 — unparseable expect"
check "neg: missing run: is a failure, not a shifted field" \
  has "$OUT" "FAIL 9.1-6 — enabled command case has no run: field"

# ---- usage errors ------------------------------------------------------------------
run_in "$FIX/empty"
check "usage: no eval files exits 2"                eq "$CODE" 2
run_in "$FIX/green" --no-such-flag
check "usage: unknown flag exits 2"                 eq "$CODE" 2

echo "-- $PASS/$((PASS + FAIL)) checks passed"
[ "$FAIL" -eq 0 ]
