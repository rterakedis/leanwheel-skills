#!/usr/bin/env bash
# budget.sh — the per-file byte budget, enforced as a ratchet (DD-72). Zero model tokens.
#
# Budget: 20 KB per .claude/skills/*/SKILL.md, 4 KB per agents/*.md. Files already over
# budget are grandfathered in budget-baseline.txt at a recorded size, and the rule that is
# enforceable today is simple: **a file over budget may not grow.** A ceiling that is broken
# on day one and never enforced is one people learn to ignore; a ratchet stops accretion now
# and lets the debt come down as it is worked.
#
# Usage:
#   bash scripts/test/budget.sh            check; exit 1 on growth or new debt
#   bash scripts/test/budget.sh --update   ratchet: lower each baseline to the current size,
#                                          retire entries now under budget. Never raises a
#                                          ceiling and never adds a file — new debt is a
#                                          deliberate hand edit to the baseline, reviewed.
#
# Exit: 0 within budget or holding · 1 a grandfathered file grew, or a new file went over

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASELINE="$ROOT/scripts/test/budget-baseline.txt"
SKILL_MAX=20480   # 20 KB
AGENT_MAX=4096    #  4 KB
UPDATE=0
[ "${1:-}" = "--update" ] && UPDATE=1
cd "$ROOT" || exit 1

ceiling_for() { awk -v p="$1" '!/^#/ && $2 == p { print $1 }' "$BASELINE"; }
size_of()     { wc -c < "$1" | tr -d ' '; }

OVER=0; HELD=0; GREW=0; NEW=0; DEBT=0; BAD=0

check_file() {  # check_file <path> <budget>
  local f="$1" max="$2" size ceil
  size="$(size_of "$f")"
  [ "$size" -le "$max" ] && return
  OVER=$((OVER + 1)); DEBT=$((DEBT + size - max))
  ceil="$(ceiling_for "$f")"
  if [ -z "$ceil" ]; then
    NEW=$((NEW + 1)); BAD=1
    echo "FAIL  $f — $size bytes, over the $max budget and not grandfathered"
  elif [ "$size" -gt "$ceil" ]; then
    GREW=$((GREW + 1)); BAD=1
    echo "FAIL  $f — grew $((size - ceil)) bytes past its ceiling ($size > $ceil)"
  elif [ "$size" -lt "$ceil" ]; then
    HELD=$((HELD + 1))
    echo "down  $f — $size, $((ceil - size)) under its ceiling; --update to ratchet"
  else
    HELD=$((HELD + 1))
    echo "held  $f — $size (budget $max)"
  fi
}

for f in .claude/skills/*/SKILL.md; do check_file "$f" "$SKILL_MAX"; done
for f in agents/*.md;               do check_file "$f" "$AGENT_MAX"; done

# Entries that no longer describe debt.
while read -r ceil f; do
  case "$ceil" in ''|\#*) continue;; esac
  if [ ! -f "$f" ]; then echo "stale $f — no longer exists; --update to retire"; continue; fi
  case "$f" in agents/*) max=$AGENT_MAX;; *) max=$SKILL_MAX;; esac
  [ "$(size_of "$f")" -le "$max" ] && echo "done  $f — now within budget; --update to retire"
done < "$BASELINE"

if [ "$UPDATE" -eq 1 ]; then
  tmp="$(mktemp)"
  while IFS= read -r line; do
    case "$line" in ''|\#*) echo "$line" >> "$tmp"; continue;; esac
    ceil="${line%% *}"; f="${line#* }"
    [ -f "$f" ] || continue
    case "$f" in agents/*) max=$AGENT_MAX;; *) max=$SKILL_MAX;; esac
    size="$(size_of "$f")"
    [ "$size" -le "$max" ] && continue                 # retired: debt paid
    [ "$size" -lt "$ceil" ] && ceil="$size"            # ratchet down, never up
    echo "$ceil $f" >> "$tmp"
  done < "$BASELINE"
  mv "$tmp" "$BASELINE"
  echo "-- baseline ratcheted"
fi

echo "BUDGET: $OVER over budget ($HELD holding, $GREW grew, $NEW new). Debt: $DEBT bytes over."
exit "$BAD"
