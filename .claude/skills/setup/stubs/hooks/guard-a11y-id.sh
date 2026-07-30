#!/usr/bin/env bash
# leanwheel guard-a11y-id — deterministic, zero-token accessibility-identifier guard.
# Wired as a PostToolUse hook on Edit|Write|MultiEdit. ADVISORY (never blocks):
# warns when a Swift file gains an interactive element or a tappable row with no
# .accessibilityIdentifier.
#
# Why this exists: the identifier convention was documented in
# docs/setup/swift/testability.md and still never adopted on a real 10-epic
# project — documentation alone doesn't change behavior. Identifiers are what make
# a simulator run deterministic (drive by identifier, never by tap coordinate), so
# the reminder has to fire at the moment the element is written, when naming it is
# nearly free. Backfilling means re-touching every screen.
#
# PostToolUse contract: exit 0 always. A non-empty stderr message is surfaced to
# the agent as feedback. Never exit 2 — a missing identifier is a smell to flag,
# not a reason to halt an edit mid-flow.

set -euo pipefail

# Only meaningful on projects carrying the testability guidance.
proj="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
[ -f "$proj/docs/setup/swift/testability.md" ] || exit 0

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

# Swift source only; test code and generated previews are not user-facing surface.
case "$file" in
  *.swift) ;;
  *) exit 0 ;;
esac
case "$file" in
  *Tests/*|*Test.swift|*Tests.swift|*UITests*) exit 0 ;;
esac

# Interactive elements and tappable rows — the things a flow needs to address.
INTERACTIVE='Button\(|Button\{|TextField\(|SecureField\(|TextEditor\(|Toggle\(|Picker\(|DatePicker\(|Stepper\(|Slider\(|Menu\(|Link\(|NavigationLink\(|\.onTapGesture|\.swipeActions|ColorPicker\(|Dropdown\('

printf '%s' "$added" | grep -Eq "$INTERACTIVE" || exit 0

# An identifier anywhere in the added chunk is good enough for an advisory check.
if printf '%s' "$added" | grep -q '\.accessibilityIdentifier'; then
  exit 0
fi

kinds="$(printf '%s' "$added" | grep -oE "$INTERACTIVE" | sed 's/[(){].*//; s/^\.//' | sort -u | tr '\n' ' ')"

echo "leanwheel a11y-id note: ${file} added interactive element(s) [${kinds}] with no .accessibilityIdentifier." >&2
echo "Add one per element and per dynamic row, kebab-case {feature}-{element}-{role} (e.g. \"invoice-save-button\", \"invoice-row-\\(item.id)\")." >&2
echo "These are how /design-verify and XCUITest flows address the UI — without them, driving the app falls back to guessing at tap coordinates." >&2
echo "If the story has a Design Contract, use the identifiers it already names. Advisory only — never blocks." >&2

exit 0
