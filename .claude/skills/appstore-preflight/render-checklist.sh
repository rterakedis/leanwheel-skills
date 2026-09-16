#!/usr/bin/env bash
# render-checklist.sh — render the App Store submission checklist from its template.
# Zero model tokens: appstore-preflight Step 7 runs this instead of reading the template.
#
# The template (submission-checklist.template.md, beside this script) carries three
# kinds of conditional marker. They are purely mechanical, so they are resolved here and
# the model only fills the judgment placeholders that remain in the rendered file.
#
#   ## Heading {omit if no StoreKit}      whole section, up to the next "## " heading
#   - [ ] … {omit if no StoreKit} …       one line   (also: {omit if no CloudKit})
#   …{+ 13" iPad set if universal}        inline text, kept only for universal apps
#
# Usage:
#   render-checklist.sh --storekit yes|no --cloudkit yes|no --universal yes|no \
#                       --date YYYY-MM-DD --out <path> [--template <path>]
#
# Output: writes <path>; each omission is noted in a blockquote under the H1.
# Last line: CHECKLIST: <path> — storekit=… cloudkit=… universal=…; <N> placeholders to fill
# Exit: 0 rendered · 1 a conditional marker survived rendering (template drift) · 2 usage

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$HERE/submission-checklist.template.md"
STOREKIT=""; CLOUDKIT=""; UNIVERSAL=""; DATE=""; OUT=""

usage() { sed -n '13,16p' "$0" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --storekit)  STOREKIT="${2:-}"; shift 2;;
    --cloudkit)  CLOUDKIT="${2:-}"; shift 2;;
    --universal) UNIVERSAL="${2:-}"; shift 2;;
    --date)      DATE="${2:-}"; shift 2;;
    --out)       OUT="${2:-}"; shift 2;;
    --template)  TEMPLATE="${2:-}"; shift 2;;
    -h|--help)   usage;;
    *) echo "unknown arg: $1" >&2; usage;;
  esac
done

for pair in "storekit:$STOREKIT" "cloudkit:$CLOUDKIT" "universal:$UNIVERSAL"; do
  case "${pair#*:}" in
    yes|no) ;;
    *) echo "--${pair%%:*} must be yes or no (got '${pair#*:}')" >&2; exit 2;;
  esac
done
case "$DATE" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
  *) echo "--date must be YYYY-MM-DD (got '$DATE')" >&2; exit 2;;
esac
[ -n "$OUT" ] || { echo "--out is required" >&2; exit 2; }
[ -f "$TEMPLATE" ] || { echo "template not found: $TEMPLATE" >&2; exit 2; }
mkdir -p "$(dirname "$OUT")" || exit 2

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

awk -v sk="$STOREKIT" -v ck="$CLOUDKIT" -v uni="$UNIVERSAL" -v date="$DATE" '
  function dropped(line) {
    return (sk == "no" && index(line, "{omit if no StoreKit}")) ||
           (ck == "no" && index(line, "{omit if no CloudKit}"))
  }
  function unmark(line) {
    gsub(/ ?\{omit if no (StoreKit|CloudKit)\} ?/, " ", line)
    sub(/^- \[ \]  +/, "- [ ] ", line)
    sub(/ +:/, ":", line)
    sub(/ +$/, "", line)
    return line
  }
  /^## / {
    skipping = 0
    if (dropped($0)) {
      skipping = 1
      title = $0; sub(/^## /, "", title); sub(/ *\{omit if no [A-Za-z]+\}/, "", title)
      notes = notes "\n> Omitted: " title " section (" (sk == "no" && index($0, "StoreKit") ? "no StoreKit" : "no CloudKit") " detected)."
      next
    }
  }
  skipping { next }
  dropped($0) {
    item = $0; sub(/^- \[ \] /, "", item); sub(/ *\{omit if no [A-Za-z]+\}:? */, " ", item)
    sub(/^ +/, "", item); item = substr(item, 1, 40)
    notes = notes "\n> Omitted: \"" item "…\" (" (index($0, "StoreKit") ? "no StoreKit" : "no CloudKit") " detected)."
    next
  }
  {
    line = unmark($0)
    while (match(line, /\{\+ [^}]* if universal\}/)) {
      inner = substr(line, RSTART + 3, RLENGTH - 3)
      sub(/ if universal\}$/, "", inner)
      line = substr(line, 1, RSTART - 1) (uni == "yes" ? " + " inner : "") substr(line, RSTART + RLENGTH)
    }
    # Only the title date is mechanical; a {date} inside a judgment placeholder (e.g. the
    # review-notes stamp) is the date something was verified, and stays for the model.
    sub(/regenerated \{date\}/, "regenerated " date, line)
    out[++n] = line
  }
  END {
    for (i = 1; i <= n; i++) {
      print out[i]
      if (i == 1 && notes != "") print substr(notes, 1)
    }
  }
' "$TEMPLATE" > "$tmp"

if grep -nE '\{omit if|if universal\}' "$tmp" >&2; then
  echo "render-checklist: conditional marker survived rendering — template and script have drifted" >&2
  exit 1
fi

mv "$tmp" "$OUT"; trap - EXIT
left="$(grep -o '{[^}]*}' "$OUT" | wc -l | tr -d ' ')"
echo "CHECKLIST: $OUT — storekit=$STOREKIT cloudkit=$CLOUDKIT universal=$UNIVERSAL; $left placeholders to fill"
