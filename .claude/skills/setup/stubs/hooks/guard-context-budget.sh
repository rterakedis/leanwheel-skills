#!/usr/bin/env bash
# leanwheel guard-context-budget — deterministic, zero-token context-budget guard.
# Wired as a PostToolUse hook on Edit|Write|MultiEdit. ADVISORY (never blocks):
# warns when a CLAUDE.md grows past its line budget. CLAUDE.md is loaded on every
# turn, so its length is paid for constantly — unlike any other file in the repo.
#
# PostToolUse contract: exit 0 always. A non-empty stderr message is surfaced to
# the agent as feedback. Never exit 2 — being over budget is a cleanup signal, not
# a reason to halt an edit mid-flow.
#
# Override the budget with LEANWHEEL_CLAUDE_MD_BUDGET (default 300).

set -euo pipefail

budget="${LEANWHEEL_CLAUDE_MD_BUDGET:-300}"

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
else
  file="$(printf '%s' "$input" | grep -oE '"file_path"[^,]*' | head -1 | sed 's/.*: *"//; s/".*//' || true)"
fi

[ -z "${file}" ] && exit 0
[ "$(basename "$file")" = "CLAUDE.md" ] || exit 0
[ -f "$file" ] || exit 0

lines="$(wc -l < "$file" | tr -d ' ')"
[ "$lines" -gt "$budget" ] || exit 0

echo "leanwheel context-budget note: ${file} is ${lines} lines, over the ${budget}-line budget." >&2
echo "CLAUDE.md loads every turn. Over budget → demote or move, don't append:" >&2
echo "  T1 (a test/hook/linter enforces it) → ≤2 lines: rule + enforcing artifact's name." >&2
echo "  T2 (repo-wide, unautomatable) → full prose stays here." >&2
echo "  T3 (one directory/feature) → move to a nested CLAUDE.md there." >&2
echo "Tiers are defined in setup/claude-template.md; /retrospective's tier audit demotes." >&2

exit 0
