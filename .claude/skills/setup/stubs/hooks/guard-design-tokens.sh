#!/usr/bin/env bash
# leanwheel guard-design-tokens — deterministic, zero-token design-system guard.
# Wired as a PostToolUse hook on Edit|Write|MultiEdit. ADVISORY (never blocks):
# warns when a UI file gains a hardcoded color literal while the project has a
# design system (docs/ux/DESIGN.md). Mirrors the swift-audit / web-audit color
# checks, moved to write-time so drift is caught before code review.
#
# PostToolUse contract: exit 0 always. A non-empty stderr message is surfaced to
# the agent as feedback. We never exit 2 here — off-token values are a smell to
# flag, not a hard error that should halt an edit mid-flow.

set -euo pipefail

# Only meaningful when a design system exists.
proj="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
[ -f "$proj/docs/ux/DESIGN.md" ] || exit 0

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

case "$file" in
  *.swift)            kind="swift" ;;
  *.css|*.scss|*.sass|*.less|*.astro|*.html|*.htm|*.vue|*.svelte|*.jsx|*.tsx) kind="web" ;;
  *)                  exit 0 ;;
esac

warn=""
if [ "$kind" = "swift" ]; then
  # Color(red:green:blue:) / Color(hex:) / UIColor(red:) literals.
  if printf '%s' "$added" | grep -Eq 'Color\((red|hex):|UIColor\(red:|\.init\(red:[0-9.]'; then
    warn="hardcoded Color(red:/hex:) literal"
  fi
else
  # Raw hex, rgb()/rgba(), hsl() literals in markup/styles.
  if printf '%s' "$added" | grep -Eiq '#[0-9a-f]{3,8}\b|rgba?\([0-9]|hsla?\([0-9]'; then
    warn="hardcoded color literal (#hex / rgb / hsl)"
  fi
fi

if [ -n "$warn" ]; then
  echo "leanwheel design-token note: ${file} added a ${warn}, but docs/ux/DESIGN.md defines a token system." >&2
  echo "Prefer a named design token. If this is intentional (one-off, third-party embed), ignore — this is advisory only." >&2
fi

exit 0
