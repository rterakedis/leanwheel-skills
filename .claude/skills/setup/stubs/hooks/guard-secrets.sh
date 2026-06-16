#!/usr/bin/env bash
# bmad-lite guard-secrets — deterministic, zero-token secret guard.
# Wired as a PreToolUse hook on Edit|Write|MultiEdit and on Bash `git commit`.
# Blocks (exit 2) when about-to-be-written content or a staged diff contains a
# hardcoded secret. Pure grep — never calls a model.
#
# Hook contract: receives the tool-call JSON on stdin. For PreToolUse, exit 2
# with a message on stderr blocks the call and feeds the message back to the
# agent; exit 0 allows it.

set -euo pipefail

input="$(cat)"

# --- extract the text we need to scan -------------------------------------
# Prefer jq when available; otherwise scan the raw payload conservatively.
# Gather candidate text: new_string / content (Edit/Write), plus command (Bash).
scan_text=""
if command -v jq >/dev/null 2>&1; then
  scan_text="$(printf '%s' "$input" | jq -r '[.tool_input.content, .tool_input.new_string, (.tool_input.edits[]?.new_string)] | map(select(. != null)) | join("\n")' 2>/dev/null || true)"
  command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
else
  # No jq: scan the whole payload conservatively.
  scan_text="$input"
  command="$input"
fi

# If this is a git commit, scan the staged diff instead of the command text.
if printf '%s' "${command:-}" | grep -Eq '\bgit\b.*\bcommit\b'; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    scan_text="$scan_text
$(git diff --cached 2>/dev/null || true)"
  fi
fi

[ -z "${scan_text// }" ] && exit 0

# --- secret signatures ----------------------------------------------------
# High-signal patterns only — kept tight to avoid false positives that would
# erode trust in the guard.
patterns=(
  'AKIA[0-9A-Z]{16}'                                   # AWS access key id
  'ASIA[0-9A-Z]{16}'                                   # AWS temp key id
  '-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----'             # PEM private key
  'gh[pousr]_[A-Za-z0-9]{36,}'                         # GitHub token
  'github_pat_[A-Za-z0-9_]{60,}'                       # GitHub fine-grained PAT
  'xox[baprs]-[A-Za-z0-9-]{10,}'                       # Slack token
  'sk-(live|proj|ant)?-?[A-Za-z0-9]{20,}'              # OpenAI / Anthropic-style
  'sk_live_[0-9a-zA-Z]{16,}'                           # Stripe live secret
  'AIza[0-9A-Za-z_-]{35}'                              # Google API key
  'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' # JWT
  '(?i)(api[_-]?key|secret|passwd|password|token)["'"'"' ]*[:=]["'"'"' ]*[A-Za-z0-9!@#$%^&*_+/-]{12,}'
)

hit=""
for p in "${patterns[@]}"; do
  if printf '%s' "$scan_text" | grep -Eq "$p" 2>/dev/null \
     || printf '%s' "$scan_text" | grep -Piq "$p" 2>/dev/null; then
    hit="$p"
    break
  fi
done

# Allow obvious placeholders / env reads — these are not real secrets.
if [ -n "$hit" ]; then
  match_line="$(printf '%s' "$scan_text" | grep -EiI "$hit" 2>/dev/null | head -1 || printf '%s' "$scan_text" | grep -PiI "$hit" 2>/dev/null | head -1 || true)"
  if printf '%s' "$match_line" | grep -Eiq '(your[_-]?|example|placeholder|xxx+|<[^>]+>|\$\{?[A-Z_]+\}?|process\.env|os\.environ|ENV\[|getenv|Secrets\.|Keychain)'; then
    exit 0
  fi
  echo "BLOCKED by bmad-lite guard-secrets: a hardcoded secret was detected (pattern: ${hit})." >&2
  echo "Move it to an environment variable, secret manager, or keychain and reference it by name." >&2
  echo "If this is a false positive (test fixture, placeholder), rename it to an obvious placeholder or commit it manually outside the agent." >&2
  exit 2
fi

exit 0
