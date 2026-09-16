#!/usr/bin/env bash
# checklist-render.sh — self-test for appstore-preflight/render-checklist.sh. Zero model tokens.
#
# The script resolves the checklist template's conditional markers so the model never reads
# the template. A marker it mishandles either leaks a `{omit if …}` into a user's checklist or
# silently drops a section that applies — so each flag is checked in both states, and the
# drift guard is checked against a template carrying a marker the script doesn't know.
#
# Usage:  bash scripts/test/checklist-render.sh
# Exit:   0 all checks pass · 1 any check failed

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
R="$ROOT/.claude/skills/appstore-preflight/render-checklist.sh"
T="$ROOT/.claude/skills/appstore-preflight/submission-checklist.template.md"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then PASS=$((PASS + 1)); echo "ok     $desc"
  else FAIL=$((FAIL + 1)); echo "NOT OK $desc"; fi
}
has()   { grep -qF -- "$2" "$1"; }
lacks() { ! grep -qF -- "$2" "$1"; }
render() { bash "$R" --storekit "$1" --cloudkit "$2" --universal "$3" --date 2026-01-02 --out "$W/$4.md"; }

# ---- the template itself carries the markers this test depends on ------------------
check "template: StoreKit section marker present"  has "$T" "## In-App Purchases {omit if no StoreKit}"
check "template: StoreKit line marker present"     has "$T" "{omit if no StoreKit} Paywall recorded"
check "template: CloudKit line marker present"     has "$T" "CloudKit schema {omit if no CloudKit}"
check "template: universal marker present"         has "$T" "{+ 13\" iPad set if universal}"

# ---- everything off ------------------------------------------------------------------
check "none: renders"                              render no no no none
check "none: date filled"                          has   "$W/none.md" "regenerated 2026-01-02 by"
check "none: IAP section dropped"                  lacks "$W/none.md" "## In-App Purchases"
check "none: IAP section body dropped too"         lacks "$W/none.md" "ATTACHED to the version"
check "none: paywall-recording line dropped"       lacks "$W/none.md" "- [ ] Paywall recorded"
check "none: CloudKit line dropped"                lacks "$W/none.md" "- [ ] CloudKit schema"
check "none: iPad set dropped"                     lacks "$W/none.md" "13\" iPad set"
check "none: iPhone set kept"                      has   "$W/none.md" "Screenshots: 6.9\" iPhone set —"
check "none: section omission noted"               has   "$W/none.md" "> Omitted: In-App Purchases section (no StoreKit detected)."
check "none: line omission noted"                  has   "$W/none.md" "(no CloudKit detected)."
check "none: section after the dropped one kept"   has   "$W/none.md" "## Signing"

# ---- everything on -------------------------------------------------------------------
check "all: renders"                               render yes yes yes all
check "all: IAP section kept, marker gone"         grep -qx "## In-App Purchases" "$W/all.md"
check "all: paywall line kept, marker gone"        has   "$W/all.md" "- [ ] Paywall recorded BEFORE"
check "all: CloudKit line kept, marker gone"       has   "$W/all.md" "- [ ] CloudKit schema: \`--init"
check "all: iPad set kept"                         has   "$W/all.md" "6.9\" iPhone set + 13\" iPad set —"
check "all: nothing noted as omitted"              lacks "$W/all.md" "Omitted:"
check "all: judgment placeholders left for the model" has "$W/all.md" "{detected SDK list}"
check "all: a {date} inside a placeholder is not the render date" has "$W/all.md" "UNVERIFIED claims ({date})"
check "all: only markers and date differ from the template" \
  [ "$(diff "$T" "$W/all.md" | grep -c '^>')" -eq 5 ]

# ---- flags are independent -----------------------------------------------------------
check "mixed: renders"                             render yes no yes mixed
check "mixed: IAP kept while CloudKit dropped"     has   "$W/mixed.md" "## In-App Purchases"
check "mixed: CloudKit dropped"                    lacks "$W/mixed.md" "- [ ] CloudKit schema"

# ---- guards --------------------------------------------------------------------------
printf '# X {date}\n- [ ] thing {omit if no HealthKit}\n' > "$W/drift.template.md"
bash "$R" --storekit no --cloudkit no --universal no --date 2026-01-02 \
  --out "$W/drift.md" --template "$W/drift.template.md" >/dev/null 2>&1; code=$?
check "drift: unknown marker fails the render (exit 1)" [ "$code" -eq 1 ]
check "drift: nothing written on failure"          [ ! -f "$W/drift.md" ]
bash "$R" --storekit maybe --cloudkit no --universal no --date 2026-01-02 --out "$W/x.md" >/dev/null 2>&1; code=$?
check "usage: bad flag value exits 2"              [ "$code" -eq 2 ]
bash "$R" --storekit no --cloudkit no --universal no --date 16/09/2026 --out "$W/x.md" >/dev/null 2>&1; code=$?
check "usage: bad date exits 2"                    [ "$code" -eq 2 ]

echo "-- $PASS/$((PASS + FAIL)) checks passed"
[ "$FAIL" -eq 0 ]
