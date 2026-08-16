#!/usr/bin/env bash
# leanwheel asc-lint — App Store Connect metadata linter.
#
# Lints docs/store/ (the /appstore-connect artifact tree) against Apple's
# App Store Connect field limits and required-file set:
#   - metadata/{locale}/*.txt char limits (name/subtitle/keywords/promotional_text/
#     description/release_notes), required-file presence per locale, keyword
#     hygiene (space-after-comma, duplicates, keyword repeating a name word)
#   - privacy_url.txt / support_url.txt / marketing_url.txt: https:// shape +
#     optional live network check (skipped with --no-network or without curl)
#   - root copyright.txt / primary_category.txt presence
#   - screenshot-captions.txt vs the id column of ../screenshots.md
#   - screenshots/{locale}/*.png filename shape + pixel size vs the accepted
#     table below (via `sips`), per-class count warning
#
# Apple limits (chars, not bytes — counted with LC_ALL=en_US.UTF-8 `wc -m`,
# one trailing newline stripped, so é/ñ/emoji each count as 1):
#   name.txt               <=30   ERROR, required
#   subtitle.txt            <=30   ERROR, optional file
#   keywords.txt            <=100  ERROR, required, comma-separated
#   promotional_text.txt    <=170  ERROR, optional file
#   description.txt         <=4000 ERROR, required
#   release_notes.txt       <=4000 ERROR, optional file (WARN if missing: required for updates)
#
# Accepted screenshot pixel sizes (portrait; landscape = swapped):
#   iphone69    1320x2868, 1290x2796
#   ipadPro13   2064x2752, 2048x2732
#
# Two modes, one file:
#   1. Standalone:  asc-lint.sh [store-dir] [--locale ll-RR] [--no-network] [--quiet]
#      Lints every locale (or one). Prints one line per finding plus a summary.
#      Exit 1 iff any ERROR, else 0.
#   2. Hook mode (PostToolUse Edit|Write|MultiEdit): stdin is not a TTY and
#      parses to tool_input.file_path. If that file is under */docs/store/,
#      lints the touched store dir (single locale if the file is under
#      metadata/{locale}/, else all locales), prints findings to stderr,
#      and ALWAYS exits 0 (advisory — never blocks). Silent when the file
#      is elsewhere or docs/store/ doesn't exist. Always runs --no-network.
#
# This is the canonical copy. .claude/skills/setup/stubs/hooks/asc-lint.sh is
# an identical copy scaffolded into projects' .claude/hooks/ by /setup — keep
# them in sync:
#   diff .claude/skills/appstore-connect/asc-lint.sh .claude/skills/setup/stubs/hooks/asc-lint.sh
#
# No jq requirement (falls back to grep/sed like guard-design-tokens.sh), no
# python, no timeout(1) (doesn't exist on macOS). macOS bash 3.2 compatible:
# no associative arrays, no mapfile, no ${var,,} (uses tr for lowercasing).

set -uo pipefail

# ---------------------------------------------------------------------------
# Finding accumulators
# ---------------------------------------------------------------------------
ERR_COUNT=0
WARN_COUNT=0
QUIET=0
NO_NETWORK=0
ONLY_LOCALE=""
HOOK_MODE=0

finding() {
  # finding LEVEL "locale/file: message"
  level="$1"; shift
  msg="$1"
  if [ "$level" = "ERROR" ]; then
    ERR_COUNT=$((ERR_COUNT + 1))
    printf 'asc-lint: ERROR %s\n' "$msg" >&2
  else
    WARN_COUNT=$((WARN_COUNT + 1))
    [ "$QUIET" = "1" ] && return 0
    printf 'asc-lint: WARN %s\n' "$msg" >&2
  fi
}

# ---------------------------------------------------------------------------
# char_count FILE — chars in file content, one trailing newline stripped,
# multi-byte-safe.
# ---------------------------------------------------------------------------
char_count() {
  LC_ALL=en_US.UTF-8 printf '%s' "$(cat "$1" 2>/dev/null)" | LC_ALL=en_US.UTF-8 wc -m | tr -d ' '
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# ---------------------------------------------------------------------------
# Mode detection: hook mode iff stdin is not a TTY and parses to
# tool_input.file_path (same detection as guard-design-tokens.sh).
# ---------------------------------------------------------------------------
STDIN_JSON=""
if [ ! -t 0 ]; then
  STDIN_JSON="$(cat)"
fi

HOOK_FILE=""
if [ -n "$STDIN_JSON" ]; then
  if command -v jq >/dev/null 2>&1; then
    HOOK_FILE="$(printf '%s' "$STDIN_JSON" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
  else
    HOOK_FILE="$(printf '%s' "$STDIN_JSON" | grep -oE '"file_path"[^,}]*' | head -1 | sed 's/.*: *"//; s/".*//' || true)"
  fi
  [ -n "$HOOK_FILE" ] && HOOK_MODE=1
fi

# ---------------------------------------------------------------------------
# Argument parsing (standalone mode; ignored args in hook mode)
# ---------------------------------------------------------------------------
STORE_DIR_ARG=""
if [ "$HOOK_MODE" = "0" ]; then
  while [ $# -gt 0 ]; do
    case "$1" in
      --locale) ONLY_LOCALE="$2"; shift 2 ;;
      --no-network) NO_NETWORK=1; shift ;;
      --quiet) QUIET=1; shift ;;
      *) STORE_DIR_ARG="$1"; shift ;;
    esac
  done
fi

proj="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

if [ "$HOOK_MODE" = "1" ]; then
  NO_NETWORK=1
  case "$HOOK_FILE" in
    */docs/store/*) ;;
    *) exit 0 ;;
  esac
  # Derive store dir = the docs/store ancestor of HOOK_FILE.
  STORE_DIR="$(printf '%s' "$HOOK_FILE" | sed -E 's#(.*/docs/store)/.*#\1#')"
  [ -d "$STORE_DIR" ] || exit 0
  # If the touched file is under metadata/{locale}/, restrict to that locale.
  case "$HOOK_FILE" in
    */docs/store/metadata/*)
      rest="${HOOK_FILE#*/docs/store/metadata/}"
      ONLY_LOCALE="${rest%%/*}"
      ;;
  esac
else
  STORE_DIR="${STORE_DIR_ARG:-$proj/docs/store}"
fi

# ---------------------------------------------------------------------------
# Root checks
# ---------------------------------------------------------------------------
if [ ! -d "$STORE_DIR/metadata" ]; then
  finding ERROR "no metadata dir — run /appstore-connect METADATA"
else
  for f in copyright.txt primary_category.txt; do
    p="$STORE_DIR/metadata/$f"
    if [ ! -s "$p" ]; then
      finding ERROR "$f: missing or empty"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Locale list
# ---------------------------------------------------------------------------
LOCALES=""
if [ -n "$ONLY_LOCALE" ]; then
  LOCALES="$ONLY_LOCALE"
elif [ -d "$STORE_DIR/metadata" ]; then
  for d in "$STORE_DIR"/metadata/*/; do
    [ -d "$d" ] || continue
    loc="$(basename "$d")"
    LOCALES="$LOCALES $loc"
  done
fi

check_url() {
  # check_url LOCALE FILE REQUIRED(0/1)
  loc="$1"; fname="$2"; required="$3"
  p="$STORE_DIR/metadata/$loc/$fname"
  if [ ! -s "$p" ]; then
    if [ "$required" = "1" ]; then
      finding ERROR "$loc/$fname: missing"
    fi
    return
  fi
  url="$(cat "$p")"
  # strip trailing whitespace/newline
  url="$(printf '%s' "$url" | tr -d '\n' | sed -e 's/[[:space:]]*$//')"
  case "$url" in
    https://*) ;;
    *) finding ERROR "$loc/$fname: must start with https:// (got: ${url:0:40})"; return ;;
  esac
  if [ "$NO_NETWORK" = "0" ]; then
    if command -v curl >/dev/null 2>&1; then
      code="$(curl -sIL --max-time 10 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "000")"
      case "$code" in
        2??|3??) ;;
        *) finding ERROR "$loc/$fname: $code — must resolve at review time" ;;
      esac
    else
      finding WARN "$loc/$fname: network check skipped (curl unavailable)"
    fi
  fi
}

check_limit() {
  # check_limit LOCALE FILE MAXCHARS REQUIRED(0/1)
  loc="$1"; fname="$2"; max="$3"; required="$4"
  p="$STORE_DIR/metadata/$loc/$fname"
  if [ ! -f "$p" ] || [ ! -s "$p" ]; then
    if [ "$required" = "1" ]; then
      finding ERROR "$loc/$fname: missing"
    elif [ "$fname" = "release_notes.txt" ]; then
      finding WARN "$loc/$fname: missing — required for updates"
    fi
    return
  fi
  n="$(char_count "$p")"
  if [ "$n" -gt "$max" ] 2>/dev/null; then
    finding ERROR "$loc/$fname: $n chars (max $max)"
  fi
}

for loc in $LOCALES; do
  d="$STORE_DIR/metadata/$loc"
  [ -d "$d" ] || { finding ERROR "$loc: metadata directory missing"; continue; }

  check_limit "$loc" name.txt 30 1
  check_limit "$loc" subtitle.txt 30 0
  check_limit "$loc" keywords.txt 100 1
  check_limit "$loc" promotional_text.txt 170 0
  check_limit "$loc" description.txt 4000 1
  check_limit "$loc" release_notes.txt 4000 0

  check_url "$loc" privacy_url.txt 1
  check_url "$loc" support_url.txt 1
  check_url "$loc" marketing_url.txt 0

  # --- keywords.txt hygiene -------------------------------------------------
  kw_file="$d/keywords.txt"
  if [ -s "$kw_file" ]; then
    kw_raw="$(cat "$kw_file" | tr -d '\n')"
    if printf '%s' "$kw_raw" | grep -q ', '; then
      finding WARN "$loc/keywords.txt: space after comma wastes chars"
    fi
    name_file="$d/name.txt"
    name_words=""
    if [ -s "$name_file" ]; then
      name_words="$(lower "$(cat "$name_file" | tr -d '\n')" | tr -cs 'a-z0-9' ' ')"
    fi

    seen=""
    IFS=','
    for kw in $kw_raw; do
      IFS=' '
      kw_trim="$(printf '%s' "$kw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      [ -z "$kw_trim" ] && continue
      kw_lc="$(lower "$kw_trim")"
      # duplicate check
      case " $seen " in
        *" $kw_lc "*) finding WARN "$loc/keywords.txt: duplicate keyword \"$kw_trim\"" ;;
      esac
      seen="$seen $kw_lc"
      # name-word repeat check (words >=3 chars)
      if [ ${#kw_lc} -ge 3 ]; then
        for w in $name_words; do
          [ ${#w} -lt 3 ] && continue
          if [ "$w" = "$kw_lc" ]; then
            finding WARN "$loc/keywords.txt: keyword \"$kw_trim\" repeats a word from name.txt — App Store already indexes the name; repeating it wastes characters"
            break
          fi
        done
      fi
      IFS=','
    done
    unset IFS
  fi

  # --- screenshot-captions.txt vs screenshots.md plan -----------------------
  plan_file="$STORE_DIR/screenshots.md"
  cap_file="$d/screenshot-captions.txt"
  if [ -f "$plan_file" ]; then
    # Extract ids: first markdown table whose header row contains "| # |" and "id".
    ids="$(awk '
      /^\|/ {
        line=$0
        if (!intable) {
          if (line ~ /\|[[:space:]]*#[[:space:]]*\|/ && tolower(line) ~ /id/) { intable=1; header=1; next }
          next
        }
        if (header==1) { header=0; next }  # separator row
        n=split(line, cols, "|")
        gsub(/^[ \t]+|[ \t]+$/, "", cols[3])
        if (cols[3] != "" && cols[3] != "---") print cols[3]
        next
      }
      { if (intable) intable=0 }
    ' "$plan_file")"

    if [ ! -f "$cap_file" ]; then
      if [ -n "$ids" ]; then
        finding WARN "$loc/screenshot-captions.txt: missing"
      fi
    else
      for id in $ids; do
        cap_line="$(grep -E "^${id}:" "$cap_file" 2>/dev/null | head -1)"
        if [ -z "$cap_line" ]; then
          finding ERROR "$loc/screenshot-captions.txt: no caption for id \"$id\""
        else
          cap_text="${cap_line#*:}"
          cap_text="$(printf '%s' "$cap_text" | sed -e 's/^[[:space:]]*//')"
          n=${#cap_text}
          if [ "$n" -gt 40 ]; then
            finding WARN "$loc/screenshot-captions.txt: caption for \"$id\" is $n chars (>40, may wrap/shrink)"
          fi
        fi
      done
    fi
  fi

  # --- screenshots/{locale}/*.png -------------------------------------------
  shot_dir="$STORE_DIR/screenshots/$loc"
  if [ -d "$shot_dir" ]; then
    count_iphone69=0
    classes_seen=""
    for f in "$shot_dir"/*.png; do
      [ -f "$f" ] || continue
      base="$(basename "$f")"
      # {n}_{class}_{id}.png
      cls="$(printf '%s' "$base" | sed -E 's/^[0-9]+_([A-Za-z0-9]+)_.*\.png$/\1/')"
      if [ "$cls" = "$base" ]; then
        finding WARN "$loc/screenshots/$base: filename doesn't match {n}_{class}_{id}.png"
        continue
      fi
      [ "$cls" = "iphone69" ] && count_iphone69=$((count_iphone69 + 1))
      classes_seen="$classes_seen $cls"

      if command -v sips >/dev/null 2>&1; then
        w="$(sips -g pixelWidth "$f" 2>/dev/null | awk '/pixelWidth/{print $2}')"
        h="$(sips -g pixelHeight "$f" 2>/dev/null | awk '/pixelHeight/{print $2}')"
        ok=0
        case "$cls" in
          iphone69)
            case "${w}x${h}" in
              1320x2868|1290x2796|2868x1320|2796x1290) ok=1 ;;
            esac
            accepted="1320x2868, 1290x2796"
            ;;
          ipadPro13)
            case "${w}x${h}" in
              2064x2752|2048x2732|2752x2064|2732x2048) ok=1 ;;
            esac
            accepted="2064x2752, 2048x2732"
            ;;
          *)
            ok=1 # unknown class — not our table to police
            accepted=""
            ;;
        esac
        if [ "$ok" = "0" ]; then
          finding ERROR "$loc/screenshots/$base: size ${w}x${h} not accepted for $cls (accepted: $accepted)"
        fi
      fi
    done

    if [ "$count_iphone69" = "0" ]; then
      finding WARN "$loc/screenshots: no iphone69 screenshots found"
    fi

    # per-class count warning (>10)
    uniq_classes="$(printf '%s\n' $classes_seen | sort -u)"
    for c in $uniq_classes; do
      [ -z "$c" ] && continue
      cnt=0
      for cc in $classes_seen; do
        [ "$cc" = "$c" ] && cnt=$((cnt + 1))
      done
      if [ "$cnt" -gt 10 ]; then
        finding WARN "$loc/screenshots: $cnt screenshots for class $c (>10)"
      fi
    done
  fi
done

# ---------------------------------------------------------------------------
# Summary + exit
# ---------------------------------------------------------------------------
if [ "$HOOK_MODE" = "1" ]; then
  if [ $((ERR_COUNT + WARN_COUNT)) -gt 0 ]; then
    printf 'asc-lint: %d errors, %d warnings\n' "$ERR_COUNT" "$WARN_COUNT" >&2
    printf 'asc-lint: advisory — run `bash .claude/hooks/asc-lint.sh docs/store` for the full report incl. URL checks\n' >&2
  fi
  exit 0
else
  printf 'asc-lint: %d errors, %d warnings\n' "$ERR_COUNT" "$WARN_COUNT" >&2
  [ "$ERR_COUNT" -gt 0 ] && exit 1
  exit 0
fi
