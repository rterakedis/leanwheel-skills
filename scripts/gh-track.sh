#!/usr/bin/env bash
# gh-track.sh — deterministic GitHub issue status tracking for leanwheel.
#
# Status labels are MUTUALLY EXCLUSIVE; an issue carries exactly one at a time:
#   backlog → ready-for-dev → in-progress → review → done
#
# Subcommands:
#   transition <issue#> <label>   Move issue to <label>, stripping every other
#                                 status label (fixes the "two status labels" drift).
#   close <issue#> [comment]      Apply 'done' + close the issue.
#   status <issue#>               Print current state + labels (JSON).
#   sync <story-glob> [--apply]   Reconcile issues to each story's frontmatter
#                                 `status:`. Default is a dry-run diff; --apply executes.
#
# Why a script: these ops must be byte-identical every run. Doing the
# "remove all stale status labels except the target" step in-model is where the
# drift bug came from. Here it is deterministic and ~zero model tokens per call.
#
# Degrades gracefully: if gh / auth / repo is unavailable it prints
# "skip: gh unavailable" and exits 0, so a flywheel run is never blocked by it.

set -euo pipefail

STATUS_LABELS=(backlog ready-for-dev in-progress review done)

die() { echo "gh-track: $*" >&2; exit 1; }

gh_ready() {
  command -v gh >/dev/null 2>&1 || return 1
  gh auth status >/dev/null 2>&1 || return 1
  gh repo view --json nameWithOwner >/dev/null 2>&1 || return 1
  return 0
}

# Echo the issue's current status labels (those in STATUS_LABELS), space-separated.
current_status_labels() {
  local issue="$1" all
  all=$(gh issue view "$issue" --json labels --jq '.labels[].name' 2>/dev/null) || return 1
  local out=()
  local l
  for l in "${STATUS_LABELS[@]}"; do
    if grep -qxF "$l" <<<"$all"; then out+=("$l"); fi
  done
  echo "${out[@]:-}"
}

is_status_label() {
  local x="$1" l
  for l in "${STATUS_LABELS[@]}"; do [[ "$x" == "$l" ]] && return 0; done
  return 1
}

cmd_transition() {
  local issue="$1" target="$2"
  [[ -n "$issue" && -n "$target" ]] || die "usage: transition <issue#> <label>"
  is_status_label "$target" || die "unknown status label: $target (expected: ${STATUS_LABELS[*]})"

  local present remove_args=() l
  present=$(current_status_labels "$issue") || die "issue #$issue not found"
  for l in $present; do
    [[ "$l" == "$target" ]] || remove_args+=(--remove-label "$l")
  done

  if [[ ${#remove_args[@]} -gt 0 ]]; then
    gh issue edit "$issue" --add-label "$target" "${remove_args[@]}" >/dev/null
  else
    gh issue edit "$issue" --add-label "$target" >/dev/null
  fi

  # Verify: target present, no other status label remains.
  local after extra=()
  after=$(current_status_labels "$issue")
  local has_target=false
  for l in $after; do
    if [[ "$l" == "$target" ]]; then has_target=true; else extra+=("$l"); fi
  done
  $has_target || die "verify failed: #$issue missing '$target' after edit"
  [[ ${#extra[@]} -eq 0 ]] || die "verify failed: #$issue still carries stale status label(s): ${extra[*]}"
  echo "#$issue → $target ✓"
}

cmd_close() {
  local issue="$1"; shift || true
  local comment="${1:-Story complete — closed by leanwheel.}"
  [[ -n "$issue" ]] || die "usage: close <issue#> [comment]"
  cmd_transition "$issue" done >/dev/null
  # Idempotent: skip if already closed.
  local state
  state=$(gh issue view "$issue" --json state --jq '.state')
  if [[ "$state" == "CLOSED" ]]; then
    echo "#$issue → done + already closed ✓"
  else
    gh issue close "$issue" --comment "$comment" >/dev/null
    echo "#$issue → done + closed ✓"
  fi
}

cmd_status() {
  local issue="$1"
  [[ -n "$issue" ]] || die "usage: status <issue#>"
  gh issue view "$issue" --json number,state,labels
}

# Map a story `status:` value to "<label> <open|closed>".
map_status() {
  case "$1" in
    draft|ready|ready-for-dev) echo "ready-for-dev open" ;;
    in-progress)               echo "in-progress open" ;;
    review)                    echo "review open" ;;
    done|complete|completed)   echo "done closed" ;;
    cancelled|canceled)        echo "done closed" ;;
    backlog|"not started"|not-started) echo "backlog open" ;;
    *)                         echo "" ;;  # unknown → skip
  esac
}

fm_value() { # tolerant scalar read: YAML frontmatter `key:` first, then legacy
             # markdown header (`**Status:**` / `**GitHub Issue:** #N`) as fallback.
  local file="$1" key="$2" v
  v=$(grep -m1 "^$key:" "$file" 2>/dev/null | sed -E "s/^$key:[[:space:]]*//")
  if [[ -z "$v" ]]; then
    case "$key" in
      status)
        v=$(grep -m1 -iE '^\*\*Status:\*\*' "$file" 2>/dev/null | sed -E 's/^\*\*[Ss]tatus:\*\*[[:space:]]*//') ;;
      github_issue)
        v=$(grep -m1 -iE '^\*\*GitHub Issue:\*\*' "$file" 2>/dev/null | grep -oE '[0-9]+' | head -1) ;;
    esac
  fi
  echo "$v" | tr -d '"' | tr -d "'" | xargs || true
}

# Normalize a status value to a bare keyword: lowercase, drop emoji/punctuation,
# keep letters/space/hyphen. "✅ Done" → "done", "In-Progress" → "in-progress".
norm_status() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z [:space:]-]//g' | xargs || true
}

cmd_sync() {
  local apply=false patterns=()
  local a
  for a in "$@"; do
    if [[ "$a" == "--apply" ]]; then apply=true; else patterns+=("$a"); fi
  done
  [[ ${#patterns[@]} -gt 0 ]] || die "usage: sync <story-glob> [--apply]"

  # Expand globs here so callers can quote the pattern (e.g. "docs/epics/5-*.md").
  local files=() p
  shopt -s nullglob
  for p in "${patterns[@]}"; do files+=($p); done
  shopt -u nullglob
  [[ ${#files[@]} -gt 0 ]] || { echo "sync: no files matched ${patterns[*]}"; return 0; }

  printf '%-40s %-6s %-14s %-14s %s\n' "STORY" "ISSUE" "CURRENT" "EXPECTED" "ACTION"
  local changed=0 insync=0 skipped=0 f
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    local status issue mapped exp_label exp_state
    status=$(norm_status "$(fm_value "$f" status)")
    issue=$(fm_value "$f" github_issue)
    [[ -n "$issue" && "$issue" != "0" ]] || { skipped=$((skipped+1)); continue; }
    mapped=$(map_status "$status")
    [[ -n "$mapped" ]] || { skipped=$((skipped+1)); continue; }
    exp_label=${mapped% *}; exp_state=${mapped#* }

    local cur_label cur_state
    cur_label=$(current_status_labels "$issue" | awk '{print $1}')
    cur_state=$(gh issue view "$issue" --json state --jq '.state' 2>/dev/null | tr '[:upper:]' '[:lower:]')
    [[ -n "$cur_state" ]] || { skipped=$((skipped+1)); continue; }

    if [[ "$cur_label" == "$exp_label" && "$cur_state" == "$exp_state" ]]; then
      insync=$((insync+1)); continue
    fi
    changed=$((changed+1))
    printf '%-40s %-6s %-14s %-14s %s\n' "$(basename "$f")" "#$issue" "${cur_label:-none}/$cur_state" "$exp_label/$exp_state" "$($apply && echo applying || echo planned)"
    if $apply; then
      cmd_transition "$issue" "$exp_label" >/dev/null
      if [[ "$exp_state" == "closed" && "$cur_state" == "open" ]]; then
        gh issue close "$issue" --comment "Synced to story status: $status" >/dev/null
      elif [[ "$exp_state" == "open" && "$cur_state" == "closed" ]]; then
        gh issue reopen "$issue" >/dev/null
      fi
    fi
  done
  echo
  echo "sync: $changed $($apply && echo applied || echo to-change), $insync in-sync, $skipped skipped (no issue#/status)."
  $apply || { [[ $changed -gt 0 ]] && echo "Dry run — re-run with --apply to execute." || true; }
}

main() {
  local sub="${1:-}"; shift || true
  if ! gh_ready; then echo "skip: gh unavailable"; exit 0; fi
  case "$sub" in
    transition) cmd_transition "$@" ;;
    close)      cmd_close "$@" ;;
    status)     cmd_status "$@" ;;
    sync)       cmd_sync "$@" ;;
    ""|-h|--help|help)
      awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0" ;;
    *) die "unknown subcommand: $sub (try: transition close status sync)" ;;
  esac
}

main "$@"
