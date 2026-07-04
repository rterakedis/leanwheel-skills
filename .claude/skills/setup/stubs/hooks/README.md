# leanwheel hooks

Deterministic, **zero-token** guardrails. These are pure bash/grep — they never
call a model — so they cost nothing to run and enforce the rules the agent is
otherwise told to "remember but often forgets." Scaffolded into a project's
`.claude/hooks/` by `/setup` (and refreshed by `/upgrade-project`); wired into
`.claude/settings.json` from `hooks-settings.json`.

| Hook | Event | Behavior |
|---|---|---|
| `guard-secrets.sh` | PreToolUse (Edit/Write/MultiEdit + Bash `git commit`) | **Blocks** (exit 2) hardcoded API keys, tokens, private keys, passwords. Allows env reads, keychain refs, and obvious placeholders. |
| `guard-design-tokens.sh` | PostToolUse (Edit/Write/MultiEdit) | **Advisory** warning when a UI file gains a hardcoded color literal while `docs/ux/DESIGN.md` exists. Never blocks. |
| `log-activity.sh` | PostToolUse (`*`) | Appends one JSON line per tool use to `docs/metrics/activity.jsonl` (only if that dir exists). Backs the observability ledger. |

## Why hooks instead of prose rules

The CLAUDE.md guardrails and the swift/web anti-pattern stubs are *advisory* — the
model can skip them. Hooks move secret-leak prevention from "the model remembers"
to "the harness guarantees," which is the agentic-engineering bar. Design-token
and activity hooks stay non-blocking so they inform without interrupting flow.

## Customizing

- Add project-specific secret patterns to the `patterns` array in `guard-secrets.sh`.
- To make the design-token check blocking on a strict project, change its final
  `exit 0` to `exit 2` — but expect it to interrupt mid-edit.
- All hooks degrade gracefully without `jq` (they fall back to raw-payload grep).
