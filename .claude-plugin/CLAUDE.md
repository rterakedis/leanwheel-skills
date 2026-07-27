# CLAUDE.md — `.claude-plugin/` (packaging)

Loaded when working with the plugin manifest or marketplace catalog. Repo-wide
rules live in the root [CLAUDE.md](../CLAUDE.md).

---

## Plugin Packaging

This repo is both a plugin and its own single-plugin marketplace, installable via
`/plugin marketplace add <repo>` then `/plugin install leanwheel@leanwheel`.

- **Skills** stay in the non-standard `.claude/skills/` (preserves the personal-symlink
  + `additionalDirectories` + upstream-sync workflow). `plugin.json` exposes them with
  `"skills": "./.claude/skills/"` — a custom directory scanned *in addition to* the
  default `skills/`. Verified: all 38 load when installed.
- **Agents** must live in the plugin-standard `agents/` at the repo root. The `agents`
  manifest field pointing at files inside `.claude/agents/` validates but the agents do
  **not** register (confirmed via `claude plugin details` showing `Agents (0)`), so they
  were moved to `agents/` and the custom field dropped.
- **marketplace.json** plugin `source` is `"./"` (must start with `./`; bare `"."` fails
  schema validation). Relative sources resolve for git-based and local-dir marketplace
  adds, but NOT direct-URL-to-`marketplace.json` distribution — share via the GitHub repo.
- **No `version`** in `plugin.json` is intentional: relative-path sources in a git
  marketplace use the commit SHA, so testers get every pushed commit on
  `/plugin marketplace update`. Add+bump a `version` only if you want explicit releases.
- After any packaging change run `claude plugin validate ./` (passes with only the
  version warning).
