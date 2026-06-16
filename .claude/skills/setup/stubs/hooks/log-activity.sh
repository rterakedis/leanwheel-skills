#!/usr/bin/env bash
# bmad-lite log-activity — deterministic, zero-token observability tap.
# Wired as a PostToolUse hook (matcher "*") AND optionally a Stop hook.
# Appends one compact JSON line per tool use to the rolling activity log. No
# model call; pure file append. The flywheel ledger (docs/metrics/) is the
# curated per-phase record; this is the raw tool-call stream that backs it.

set -euo pipefail

proj="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
log_dir="$proj/docs/metrics"
log_file="$log_dir/activity.jsonl"

# Stay silent if the metrics dir was never scaffolded — observability is opt-in.
[ -d "$log_dir" ] || exit 0

input="$(cat)"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if command -v jq >/dev/null 2>&1; then
  tool="$(printf '%s' "$input" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo unknown)"
  file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
  printf '{"ts":"%s","tool":"%s","file":"%s"}\n' "$ts" "$tool" "$file" >> "$log_file"
else
  tool="$(printf '%s' "$input" | grep -oE '"tool_name"[^,]*' | head -1 | sed 's/.*: *"//; s/".*//' || echo unknown)"
  printf '{"ts":"%s","tool":"%s"}\n' "$ts" "${tool:-unknown}" >> "$log_file"
fi

# Cap the file so it never grows unbounded (keep last 2000 lines).
if [ "$(wc -l < "$log_file" 2>/dev/null || echo 0)" -gt 2000 ]; then
  tail -n 2000 "$log_file" > "$log_file.tmp" && mv "$log_file.tmp" "$log_file"
fi

exit 0
