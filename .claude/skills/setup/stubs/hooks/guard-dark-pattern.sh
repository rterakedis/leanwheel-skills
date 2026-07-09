#!/usr/bin/env bash
# leanwheel guard-dark-pattern — deterministic, zero-token dark-pattern smell check.
# Wired as a PostToolUse hook on Edit|Write|MultiEdit. ADVISORY (never blocks):
# flags the two highest-signal *textual* tells of manipulative UX — confirmshaming
# (guilt-decline) copy and pre-checked marketing/consent opt-ins — in UI files.
# Semantic dark patterns (fake progress, decoy pricing, contrast anchoring) can't be
# grepped; those are caught at design time in EXPERIENCE.md's Engagement & Persuasion
# section and adversarially in /code-review Pass E.
#
# PostToolUse contract: exit 0 always. A non-empty stderr message is surfaced to the
# agent as feedback. We never exit 2 — a dark-pattern smell is something to flag and
# let the human judge, not a hard error that halts the edit.

set -euo pipefail

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
  added="$(printf '%s' "$input" | jq -r '[.tool_input.content, .tool_input.new_string, (.tool_input.edits[]?.new_string)] | map(select(. != null)) | join("\n")' 2>/dev/null || true)"
else
  file="$(printf '%s' "$input" | grep -oE '"file_path"[^,]*' | head -1 | sed 's/.*: *"//; s/".*//' || true)"
  added="$input"
fi

[ -z "${file}" ] && exit 0
[ -z "${added// }" ] && exit 0

# UI-bearing source only. Deliberately exclude .md so planning docs / content that
# *discuss* dark patterns don't trip the hook.
case "$file" in
  *.swift|*.css|*.scss|*.sass|*.less|*.astro|*.html|*.htm|*.vue|*.svelte|*.jsx|*.tsx) : ;;
  *) exit 0 ;;
esac

warns=""

# 1. Confirmshaming / guilt-decline copy — a decline framed to shame the user out of it.
if printf '%s' "$added" | grep -Eiq "i don'?t want|i do not want|i'?ll pay full|no thanks,? i|i'?ll risk it|i (don'?t|do not) (care|need)|rather (not save|pay full|miss)|prefer to (miss|pay full)|don'?t like (saving|discounts|money)"; then
  warns="${warns}
  - confirmshaming copy — a decline option framed to guilt the user"
fi

# 2. Pre-checked marketing / consent opt-in (web markup or a Swift Toggle defaulting on).
if printf '%s' "$added" | grep -Eiq '\bchecked\b|\bdefaultChecked\b|isOn:[[:space:]]*\.constant\(true\)'; then
  if printf '%s' "$added" | grep -Eiq 'newsletter|subscribe|marketing|promotion|opt.?in|consent|add.?on|mailing list|upgrade'; then
    warns="${warns}
  - a pre-checked marketing/consent/add-on opt-in — defaults must not pre-select a paid or consent choice"
  fi
fi

if [ -n "$warns" ]; then
  echo "leanwheel dark-pattern note: ${file}${warns}" >&2
  echo "If intentional and honest (aligns the user's interest with the business's), ignore — advisory only. See EXPERIENCE.md ## Engagement & Persuasion." >&2
fi

exit 0
