#!/usr/bin/env bash
# status.sh — deterministic project status for leanwheel (DD-69).
#
# Modes:
#   status.sh                Full dashboard (epics, stories, next action).
#   status.sh --line         One line for the Claude Code status line. Always fast,
#                            always offline, prints nothing outside a leanwheel project.
#   status.sh --json         Machine-readable snapshot (one JSON object).
#   status.sh --drift        Compare story frontmatter against GitHub issue labels/state
#                            and report mismatches. The only mode that touches the network.
#
# Flags: --no-color | --color   override TTY detection      -h | --help
#
# Why a script: /status re-derived the same counts in-model on every invocation —
# a turn's latency and tokens to answer "where am I?". The rendering is deterministic,
# so it belongs in shell (same split as gh-track.sh/DD-62); the skill keeps the
# judgment half (what to run next, when to route to /next).
#
# Why frontmatter and not GitHub: each story's YAML `status:` IS the source of truth
# (DD-51) — github-tracking SYNC reconciles GitHub *to* it, never the reverse. Reading
# it locally makes every mode above work with no gh, no auth, no network, and no cache
# to go stale. --drift is where the two are compared on purpose.
#
# Degrades quietly: no docs/epics/ and no docs/epics.md means this is not a leanwheel
# project, so --line prints nothing and the others say so and exit 0. Nothing here
# blocks a session or a flywheel run.

set -euo pipefail

MODE=dashboard
COLOR=auto
SEP=$'\037'   # unit separator: never appears in a title, never collapses in `read`

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --line)      MODE=line ;;
    --json)      MODE=json ;;
    --drift)     MODE=drift ;;
    --dashboard) MODE=dashboard ;;
    --no-color)  COLOR=never ;;
    --color)     COLOR=always ;;
    -h|--help)   usage ;;
    *) echo "status: unknown argument '$1' (try --help)" >&2; exit 2 ;;
  esac
  shift
done

# Run from the project root regardless of the caller's cwd. Claude Code pipes its
# session JSON to a status line command; `workspace.project_dir` in it is the
# directory Claude was launched in, which beats cwd when the session has moved.
# No jq dependency — one grep, and any failure just falls through to git/PWD.
if [ "$MODE" = line ] && [ ! -t 0 ]; then
  STDIN_JSON=$(cat 2>/dev/null || true)
  HINT=$(printf '%s' "$STDIN_JSON" \
    | grep -o '"project_dir"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 | sed 's/.*"\([^"]*\)"$/\1/') || HINT=
  [ -n "${HINT:-}" ] && [ -d "$HINT" ] && cd "$HINT"
fi

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || ROOT=$PWD
cd "$ROOT"

STORY_DIR=docs/epics
EPICS_DOC=docs/epics.md

# ---------------------------------------------------------------- color

use_color() {
  case "$COLOR" in
    always) return 0 ;;
    never)  return 1 ;;
    *) [ -n "${NO_COLOR:-}" ] && return 1
       [ "$MODE" = line ] && return 0     # Claude Code renders ANSI in the status line
       [ -t 1 ] ;;
  esac
}

if use_color; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_RED=$'\033[31m'
else
  C_RESET=; C_DIM=; C_BOLD=; C_GREEN=; C_YELLOW=; C_BLUE=; C_RED=
fi

# ---------------------------------------------------------------- collect

# Emits TSV: epic \t story \t status \t issue \t title \t file
# Story files own the truth; docs/epics.md contributes planned-but-not-yet-created
# stories so a fresh epic doesn't read as "0 stories".
collect() {
  {
    if [ -d "$STORY_DIR" ]; then
      find "$STORY_DIR" -maxdepth 1 -type f -name '*.md' ! -name 'epic-*-context.md' -print0 2>/dev/null \
        | xargs -0 awk -v SEP="$SEP" '
            FNR==1 { fm=0; done=0; epic=""; story=""; status=""; title=""; issue="" }
            done { next }
            FNR==1 && $0 ~ /^---[ \t]*$/ { fm=1; next }
            fm && $0 ~ /^---[ \t]*$/ {
              if (epic != "" && story != "") {
                if (status == "") status = "unknown"
                printf "%s%s%s%s%s%s%s%s%s%s%s\n", epic,SEP,story,SEP,status,SEP,issue,SEP,title,SEP,FILENAME
              }
              done=1; next
            }
            fm {
              i = index($0, ":"); if (i == 0) next
              k = substr($0, 1, i-1); v = substr($0, i+1)
              gsub(/^[ \t]+|[ \t]+$/, "", k); gsub(/^[ \t]+|[ \t]+$/, "", v)
              gsub(/^["'"'"']|["'"'"']$/, "", v)
              if      (k == "epic")         epic   = v
              else if (k == "story")        story  = v
              else if (k == "status")       status = tolower(v)
              else if (k == "title")        title  = v
              else if (k == "github_issue") issue  = v
            }
          ' 2>/dev/null
    fi

    # Planned stories from docs/epics.md. A collapsed epic (DD-55) is a summary table
    # whose rows already have files, so headings alone are the right thing to scan.
    if [ -f "$EPICS_DOC" ]; then
      awk -v SEP="$SEP" '
        /^###[ \t]+Story[ \t]+[0-9]+\.[0-9]+/ {
          line = $0
          sub(/^###[ \t]+Story[ \t]+/, "", line)
          i = index(line, ":")
          if (i > 0) { id = substr(line, 1, i-1); t = substr(line, i+1) } else { id = line; t = "" }
          gsub(/^[ \t]+|[ \t]+$/, "", id); gsub(/^[ \t]+|[ \t]+$/, "", t)
          d = index(id, ".")
          if (d > 0) printf "%s%s%s%splanned%s0%s%s%s-\n", substr(id,1,d-1),SEP,substr(id,d+1),SEP,SEP,SEP,t,SEP
        }
      ' "$EPICS_DOC" 2>/dev/null
    fi
  } | awk -F"$SEP" -v SEP="$SEP" '
      # A story file always wins over the docs/epics.md heading for the same id.
      { key = $1 "." $2
        if ($3 == "planned") { if (!(key in seen)) { planned[key] = $0 } }
        else { seen[key] = 1; print }
      }
      END { for (k in planned) if (!(k in seen)) print planned[k] }
    ' \
  | sort -t"$SEP" -k1,1n -k2,2n
}

STORIES=$(collect || true)

if [ -z "$STORIES" ]; then
  case "$MODE" in
    line) exit 0 ;;                       # not a leanwheel project — show nothing
    json) echo '{"leanwheel":false,"stories":[],"epics":[]}' ; exit 0 ;;
    *) echo "status: no stories found (expected $STORY_DIR/*.md or $EPICS_DOC)."
       echo "        Run /epics to plan them, or /setup if this project isn't scaffolded yet."
       exit 0 ;;
  esac
fi

# ---------------------------------------------------------------- classify

# done|complete|cancelled → done. Everything else is open; `unknown` means a story
# file with no status: line, which is a real defect worth seeing rather than hiding.
is_done() { case "$1" in done|complete|cancelled) return 0 ;; *) return 1 ;; esac; }

icon_for() {
  case "$1" in
    done|complete)   printf '%s' "✅" ;;
    cancelled)       printf '%s' "🚫" ;;
    in-progress)     printf '%s' "🔄" ;;
    review)          printf '%s' "👀" ;;
    ready-for-dev|ready|draft) printf '%s' "📋" ;;
    planned)         printf '%s' "🔲" ;;
    *)               printf '%s' "❓" ;;
  esac
}

color_for() {
  case "$1" in
    done|complete)             printf '%s' "$C_GREEN" ;;
    in-progress)               printf '%s' "$C_YELLOW" ;;
    review)                    printf '%s' "$C_BLUE" ;;
    cancelled|unknown)         printf '%s' "$C_RED" ;;
    *)                         printf '%s' "" ;;
  esac
}

TOTAL=0; DONE=0
while IFS=$SEP read -r epic story status issue title file; do
  [ -z "${epic:-}" ] && continue
  TOTAL=$((TOTAL + 1))
  is_done "$status" && DONE=$((DONE + 1))
done <<EOF
$STORIES
EOF

# The story the session is actually on, by priority: in-progress > review > ready > planned.
current_story() {
  local want
  for want in in-progress review ready-for-dev ready draft unknown planned; do
    while IFS=$SEP read -r epic story status issue title file; do
      [ "${status:-}" = "$want" ] && { printf '%s%s%s%s%s%s%s\n' "$epic" "$SEP" "$story" "$SEP" "$status" "$SEP" "$title"; return 0; }
    done <<EOF
$STORIES
EOF
  done
  return 1
}

epic_counts() {  # $1=epic → "done total"
  awk -F"$SEP" -v e="$1" '
    $1 == e { t++; if ($3 == "done" || $3 == "complete" || $3 == "cancelled") d++ }
    END { printf "%d %d\n", d+0, t+0 }
  ' <<EOF
$STORIES
EOF
}

epic_title() {  # $1=epic → title from docs/epics.md, empty if absent
  [ -f "$EPICS_DOC" ] || return 0
  awk -v e="$1" '
    $0 ~ "^##[ \t]+Epic[ \t]+" e "[:.]" {
      line = $0; i = index(line, ":")
      if (i > 0) { t = substr(line, i+1); gsub(/^[ \t]+|[ \t]+$/, "", t); print t }
      exit
    }
  ' "$EPICS_DOC" 2>/dev/null
}

# ---------------------------------------------------------------- line

if [ "$MODE" = line ]; then
  if CUR=$(current_story); then
    IFS=$SEP read -r cepic cstory cstatus ctitle <<EOF
$CUR
EOF
    read -r edone etotal <<EOF
$(epic_counts "$cepic")
EOF
    printf '%s⚙ Epic %s%s %s▸%s %s/%s %s▸%s %s%s.%s %s%s\n' \
      "$C_DIM" "$cepic" "$C_RESET" \
      "$C_DIM" "$C_RESET" "$edone" "$etotal" \
      "$C_DIM" "$C_RESET" \
      "$(color_for "$cstatus")" "$cepic" "$cstory" "$cstatus" "$C_RESET"
  else
    printf '%s⚙ %s/%s stories done%s\n' "$C_GREEN" "$DONE" "$TOTAL" "$C_RESET"
  fi
  exit 0
fi

# ---------------------------------------------------------------- json

if [ "$MODE" = json ]; then
  printf '{"leanwheel":true,"total":%d,"done":%d,"stories":[' "$TOTAL" "$DONE"
  first=1
  while IFS=$SEP read -r epic story status issue title file; do
    [ -z "${epic:-}" ] && continue
    [ $first -eq 1 ] || printf ','
    first=0
    esc_title=$(printf '%s' "${title:-}" | sed 's/\\/\\\\/g; s/"/\\"/g')
    num=${issue:-0}; case "$num" in ''|*[!0-9]*) num=0 ;; esac
    printf '{"epic":%s,"story":%s,"status":"%s","issue":%s,"title":"%s","file":"%s"}' \
      "$epic" "$story" "$status" "$num" "$esc_title" "$(case "${file:-}" in -) echo "" ;; *) printf %s "${file:-}" ;; esac)"
  done <<EOF
$STORIES
EOF
  printf ']}\n'
  exit 0
fi

# ---------------------------------------------------------------- drift

if [ "$MODE" = drift ]; then
  if ! command -v gh >/dev/null 2>&1 \
     || ! gh auth status >/dev/null 2>&1 \
     || ! gh repo view --json nameWithOwner >/dev/null 2>&1; then
    echo "status: gh unavailable or not authenticated — skipping drift check."
    exit 0
  fi

  # Expected GitHub label + state per frontmatter status (github-tracking SYNC's table).
  expected_label() {
    case "$1" in
      draft|ready|ready-for-dev) echo "ready-for-dev open" ;;
      in-progress)               echo "in-progress open" ;;
      review)                    echo "review open" ;;
      done|complete|cancelled)   echo "done closed" ;;
      *)                         echo "- -" ;;
    esac
  }

  drifted=0
  while IFS=$SEP read -r epic story status issue title file; do
    [ -z "${epic:-}" ] && continue
    case "${issue:-0}" in ''|*[!0-9]*|0) continue ;; esac
    read -r want_label want_state <<EOF
$(expected_label "$status")
EOF
    [ "$want_label" = "-" ] && continue
    actual=$(gh issue view "$issue" --json state,labels \
               --jq '(.state|ascii_downcase) + " " + ([.labels[].name] | join(","))' 2>/dev/null) || continue
    act_state=${actual%% *}; act_labels=${actual#* }
    if [ "$act_state" != "$want_state" ] || ! printf '%s' ",$act_labels," | grep -q ",$want_label,"; then
      printf '%sDRIFT%s  #%s  %s.%s  frontmatter=%s  →  github=%s [%s]\n' \
        "$C_RED" "$C_RESET" "$issue" "$epic" "$story" "$status" "$act_state" "$act_labels"
      drifted=$((drifted + 1))
    fi
  done <<EOF
$STORIES
EOF

  if [ "$drifted" -eq 0 ]; then
    printf '%sIn sync%s — every tracked story matches its GitHub issue.\n' "$C_GREEN" "$C_RESET"
  else
    printf '\n%d issue(s) drifted. Fix with: /github-tracking sync\n' "$drifted"
  fi
  exit 0
fi

# ---------------------------------------------------------------- dashboard

REPO=$(git config --get remote.origin.url 2>/dev/null | sed 's#.*[:/]\([^/]*/[^/]*\)$#\1#; s#\.git$##') || REPO=
printf '%sPROJECT STATUS%s  %s  %s\n' "$C_BOLD" "$C_RESET" "${REPO:-$(basename "$ROOT")}" "$(date +%Y-%m-%d)"

CURRENT_EPICS=$(awk -F"$SEP" '{ print $1 }' <<EOF | sort -un
$STORIES
EOF
)

for e in $CURRENT_EPICS; do
  read -r edone etotal <<EOF
$(epic_counts "$e")
EOF
  et=$(epic_title "$e")
  printf '\n%sEpic %s%s%s  [%s/%s done]\n' \
    "$C_BOLD" "$e" "${et:+: $et}" "$C_RESET" "$edone" "$etotal"
  while IFS=$SEP read -r epic story status issue title file; do
    [ "${epic:-}" = "$e" ] || continue
    ref="-"
    [ -n "${issue:-}" ] && [ "${issue:-0}" != "0" ] && ref="#$issue"
    printf '  %-5s %s %s%-14s%s %s.%s: %s\n' \
      "$ref" "$(icon_for "$status")" "$(color_for "$status")" "$status" "$C_RESET" \
      "$epic" "$story" "${title:-}"
  done <<EOF
$STORIES
EOF
done

printf '\n%sOVERALL%s  %s/%s stories done\n' "$C_BOLD" "$C_RESET" "$DONE" "$TOTAL"

if CUR=$(current_story); then
  IFS=$SEP read -r cepic cstory cstatus ctitle <<EOF
$CUR
EOF
  case "$cstatus" in
    review)                    next="/code-review $cepic.$cstory" ;;
    in-progress)               next="/dev-story continue $cepic.$cstory" ;;
    ready-for-dev|ready|draft) next="/dev-story start $cepic.$cstory" ;;
    planned)                   next="/create-story $cepic.$cstory" ;;
    *)                         next="/next  (story $cepic.$cstory has status '$cstatus')" ;;
  esac
  printf 'NEXT     %s\n' "$next"
else
  printf 'NEXT     %s  (all stories done)\n' "/retrospective"
fi
