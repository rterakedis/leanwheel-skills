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
| `guard-dark-pattern.sh` | PostToolUse (Edit/Write/MultiEdit) | **Advisory** warning when a UI file gains confirmshaming (guilt-decline) copy or a pre-checked marketing/consent opt-in. Never blocks. Semantic dark patterns are caught at design time in EXPERIENCE.md's Engagement & Persuasion section and adversarially in `/code-review` Pass E. |
| `guard-a11y-id.sh` | PostToolUse (Edit/Write/MultiEdit) | **Advisory** warning when a Swift file gains an interactive element or tappable row with no `.accessibilityIdentifier`, on projects carrying `docs/setup/swift/testability.md`. Never blocks. Identifiers are what let `/design-verify` and XCUITest flows drive the app by name instead of by tap coordinate — and they are near-free to add at write time, expensive to backfill. |
| `asc-lint.sh` | PostToolUse (Edit/Write/MultiEdit) | **Advisory** App Store Connect metadata lint (name/subtitle/keywords/promo/description char limits, required files per locale, URL shape, screenshot sizes) whenever a file under `docs/store/` is written. Never blocks. Also runnable standalone (`bash .claude/hooks/asc-lint.sh docs/store`), where it exits 1 on errors and additionally checks that `privacy_url.txt`/`support_url.txt`/`marketing_url.txt` resolve live. Silent on projects without `docs/store/`. |
| `guard-context-budget.sh` | PostToolUse (Edit/Write/MultiEdit) | **Advisory** warning when a `CLAUDE.md` is written past its line budget (300 by default; override with `LEANWHEEL_CLAUDE_MD_BUDGET`). Never blocks. CLAUDE.md is loaded every turn, so its length is paid for constantly — the message names the T1/T2/T3 tier system from `setup/claude-template.md` and points at `/retrospective`'s tier audit: over budget → demote or move, don't append. |
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
