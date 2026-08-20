#!/usr/bin/env bash
# ledger.sh — normalized append to docs/metrics/flywheel-ledger.jsonl.
#
# Field drift observed on a real project made the ledger unqueryable (10 model-name
# variants, 6 phase-key shapes, free-text build_test, hand-rolled timestamps) — see
# DD-62. Skills call this instead of hand-writing JSON; the script owns the schema.
#
# Usage:
#   ledger.sh <phase> --story <id> [flags]
#
# Phases: create-story | dev-story | code-review | story-flywheel | epic-flywheel
#
# Flags (all optional unless noted):
#   --story <id>            required — story id ("11.3") or slug
#   --model <name>          model the phase ran on (normalized; required except flywheel roll-ups)
#   --models <k=v,k=v>      flywheel roll-ups only: per-phase models, e.g. create=sonnet,dev=opus
#   --build-test <v>        green | red | manual-required | blocked | n/a
#   --build-detail <text>   short qualifier ("233/233", "doc-only patch") — NOT a status
#   --bt-iterations <n>     dev-story: Build & Test Gate re-runs before green
#   --evals <P/T|n/a>       command evals passed/total
#   --invariants <V/T|n/a>  invariants verified/total
#   --rubric-gate <v>       PASS | FAIL | n/a   (code-review / roll-ups)
#   --patched <n> --decisions <n> --deferred <n>   finding counts (default 0)
#   --unresolved <n>        roll-ups only
#   --standalone            code-review: independent standalone pass (vs inline)
#   --docs-updated <a,b,c>  comma-separated paths
#   --duration-min <n>
#   --tests <text>          roll-ups: suite summary ("1139/85 suites")
#   --notes <text>          truncated to 300 chars — detail belongs in the story file
#
# Gate integrity (verify-green rule, code-review → Verify green): --rubric-gate PASS
# with --build-test red or blocked is refused. A gate is only PASS once the re-run
# is green (or n/a for a no-code patch); a blocked verify caps the review at
# in-progress — record FAIL or omit the gate, never a qualified PASS.
#
# Timestamps are generated here (UTC) — never passed in.
# Appends one line; prints it. If docs/metrics/ is absent, exits 0 with a note.
set -euo pipefail

LEDGER_DIR="docs/metrics"
LEDGER_FILE="$LEDGER_DIR/flywheel-ledger.jsonl"

die() { echo "ledger.sh: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq is required"

[ $# -ge 1 ] || die "usage: ledger.sh <phase> --story <id> [flags]"
PHASE="$1"; shift
case "$PHASE" in
  create-story|dev-story|code-review|story-flywheel|epic-flywheel) ;;
  *) die "invalid phase '$PHASE' (create-story|dev-story|code-review|story-flywheel|epic-flywheel)" ;;
esac

STORY="" MODEL="" MODELS="" BUILD_TEST="" BUILD_DETAIL="" EVALS="" INVARIANTS=""
RUBRIC_GATE="" DOCS_UPDATED="" NOTES="" TESTS="" STANDALONE=""
PATCHED="" DECISIONS="" DEFERRED="" UNRESOLVED="" BT_ITER="" DURATION=""

need() { [ $# -ge 2 ] || die "flag $1 needs a value"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --story)         need "$@"; STORY="$2"; shift 2 ;;
    --model)         need "$@"; MODEL="$2"; shift 2 ;;
    --models)        need "$@"; MODELS="$2"; shift 2 ;;
    --build-test)    need "$@"; BUILD_TEST="$2"; shift 2 ;;
    --build-detail)  need "$@"; BUILD_DETAIL="$2"; shift 2 ;;
    --bt-iterations) need "$@"; BT_ITER="$2"; shift 2 ;;
    --evals)         need "$@"; EVALS="$2"; shift 2 ;;
    --invariants)    need "$@"; INVARIANTS="$2"; shift 2 ;;
    --rubric-gate)   need "$@"; RUBRIC_GATE="$2"; shift 2 ;;
    --patched)       need "$@"; PATCHED="$2"; shift 2 ;;
    --decisions)     need "$@"; DECISIONS="$2"; shift 2 ;;
    --deferred)      need "$@"; DEFERRED="$2"; shift 2 ;;
    --unresolved)    need "$@"; UNRESOLVED="$2"; shift 2 ;;
    --standalone)    STANDALONE="true"; shift ;;
    --docs-updated)  need "$@"; DOCS_UPDATED="$2"; shift 2 ;;
    --duration-min)  need "$@"; DURATION="$2"; shift 2 ;;
    --tests)         need "$@"; TESTS="$2"; shift 2 ;;
    --notes)         need "$@"; NOTES="$2"; shift 2 ;;
    *) die "unknown flag '$1'" ;;
  esac
done

[ -n "$STORY" ] || die "--story is required"

# --- validation -------------------------------------------------------------
int_or_die() { [ -z "$2" ] || [[ "$2" =~ ^[0-9]+$ ]] || die "$1 must be an integer, got '$2'"; }
ratio_or_die() { [ -z "$2" ] || [[ "$2" =~ ^([0-9]+/[0-9]+|n/a)$ ]] || die "$1 must be P/T or n/a, got '$2' (detail goes in --notes)"; }

case "$PHASE" in
  story-flywheel|epic-flywheel)
    [ -n "$MODEL$MODELS" ] || die "--model or --models is required" ;;
  *)
    [ -n "$MODEL" ] || die "--model is required"
    [ -z "$MODELS" ] || die "--models is only for flywheel roll-ups" ;;
esac

[ -n "$BUILD_TEST" ] || die "--build-test is required"
case "$BUILD_TEST" in
  green|red|manual-required|blocked|n/a) ;;
  *) die "--build-test must be green|red|manual-required|blocked|n/a (qualifiers go in --build-detail)" ;;
esac

if [ -n "$RUBRIC_GATE" ]; then
  case "$RUBRIC_GATE" in
    PASS|FAIL|n/a) ;;
    *) die "--rubric-gate must be PASS|FAIL|n/a — no qualified values" ;;
  esac
  if [ "$RUBRIC_GATE" = "PASS" ] && { [ "$BUILD_TEST" = "red" ] || [ "$BUILD_TEST" = "blocked" ]; }; then
    die "verify-green rule: rubric_gate PASS requires a green (or n/a) build_test — a blocked/red verify caps the review at in-progress. Record FAIL or omit the gate."
  fi
fi

ratio_or_die "--evals" "$EVALS"
ratio_or_die "--invariants" "$INVARIANTS"
int_or_die "--bt-iterations" "$BT_ITER"
int_or_die "--patched" "$PATCHED"
int_or_die "--decisions" "$DECISIONS"
int_or_die "--deferred" "$DEFERRED"
int_or_die "--unresolved" "$UNRESOLVED"
int_or_die "--duration-min" "$DURATION"

if [ "${#NOTES}" -gt 300 ]; then
  echo "ledger.sh: notes truncated to 300 chars — detail belongs in the story file's Review Findings" >&2
  NOTES="${NOTES:0:297}..."
fi

# --- normalization ----------------------------------------------------------
# "claude-opus-4-8" / "opus-4.8" / "Opus" → "opus-4-8" / "opus"
norm_model() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/^claude-//' -e 's/\./-/g' -e 's/[[:space:]]//g'; }
[ -z "$MODEL" ] || MODEL="$(norm_model "$MODEL")"

MODELS_JSON="null"
if [ -n "$MODELS" ]; then
  MODELS_JSON="$(printf '%s' "$MODELS" | jq -Rc 'split(",") | map(split("=") | {(.[0]): (.[1] // "" | ascii_downcase | sub("^claude-"; "") | gsub("\\."; "-"))}) | add')" \
    || die "--models must be k=v,k=v (e.g. create=sonnet,dev=opus)"
fi

DOCS_JSON="null"
[ -z "$DOCS_UPDATED" ] || DOCS_JSON="$(printf '%s' "$DOCS_UPDATED" | jq -Rc 'split(",") | map(select(length > 0))')"

# dev-story and code-review always carry a findings object (counts default 0)
FINDINGS_JSON="null"
case "$PHASE" in
  dev-story|code-review)
    FINDINGS_JSON="$(jq -nc --argjson p "${PATCHED:-0}" --argjson d "${DECISIONS:-0}" --argjson w "${DEFERRED:-0}" \
      '{patched: $p, decisions: $d, deferred: $w}')"
    DEFERRED="" ;;  # consumed into findings; top-level deferred is roll-up-only
esac

# --- append -----------------------------------------------------------------
if [ ! -d "$LEDGER_DIR" ]; then
  echo "ledger.sh: no $LEDGER_DIR/ — skipped (not a metrics-enabled project)"
  exit 0
fi

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

LINE="$(jq -nc \
  --arg ts "$TS" --arg story "$STORY" --arg phase "$PHASE" --arg model "$MODEL" \
  --arg build_test "$BUILD_TEST" --arg build_detail "$BUILD_DETAIL" \
  --arg evals "$EVALS" --arg invariants "$INVARIANTS" --arg rubric_gate "$RUBRIC_GATE" \
  --arg notes "$NOTES" --arg tests "$TESTS" --arg standalone "$STANDALONE" \
  --argjson models "$MODELS_JSON" --argjson docs "$DOCS_JSON" --argjson findings "$FINDINGS_JSON" \
  --argjson bt "${BT_ITER:-null}" --argjson dur "${DURATION:-null}" \
  --argjson unresolved "${UNRESOLVED:-null}" --argjson deferred "${DEFERRED:-null}" \
  '{ts: $ts, story: $story, phase: $phase, model: $model, models: $models,
    build_test: $build_test, build_detail: $build_detail, bt_iterations: $bt,
    evals: $evals, invariants: $invariants, findings: $findings,
    rubric_gate: $rubric_gate, standalone: ($standalone == "true" // null),
    deferred: $deferred, unresolved: $unresolved, tests: $tests,
    docs_updated: $docs, duration_min: $dur, notes: $notes}
   | with_entries(select(.value != null and .value != "" and .value != false))')"

printf '%s\n' "$LINE" >> "$LEDGER_FILE"
echo "$LINE"
