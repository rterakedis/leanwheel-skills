# {project_name}

{project_description}

<!-- How this file is maintained — read before adding a rule.
This file is loaded every turn, so every line is paid for constantly. Each rule gets a tier:
  T1 — a test, hook, linter, or type already enforces it. Root carries ≤2 lines: the rule as
       one clause + the enforcing artifact's name. The full explanation lives in that
       artifact's doc comment, where someone debugging a failure actually reads it.
  T2 — cannot be automated, applies repo-wide. Full prose here — the only tier that earns
       real estate in this file.
  T3 — applies to one directory/feature. Lives in a nested CLAUDE.md there. Root keeps at most
       a one-line invariant, and only if violating it corrupts data rather than drifting style:
       nested files load lazily (possibly after the model has formed a plan), so T3 trades a
       guarantee for size — safety-critical tripwires stay in root.
Budget: ≤300 lines. Over budget means demote (T2→T1) or move (T3→nested), never append.
/retrospective audits tiers + budget at every epic close. The Simplicity doctrine lives at
`docs/setup/simplicity.md` — link it, never inline it.
-->

---

## Docs Structure

Planning and reference docs live in `docs/`. See `AGENTS.md` for the full map.

| Path | Contains |
|------|---------|
| `docs/project/` | Upstream inputs — briefs, research, ADRs, notes (read by `/prd` and `/architecture`) |
| `docs/prd.md` | Product requirements (generated from `docs/project/`) |
| `docs/architecture.md` | Tech stack, patterns, conventions |
| `docs/epics.md` | Epics and story breakdown |
| `docs/setup/` | Local dev setup, scripts, resources |
| `docs/maintainer/` | Operational runbooks |
| `docs/sql/` | Schema, migrations |
| `docs/epics/` | Story files (`{epic}-{story}-{slug}.md`) |
| `docs/specs/` | Quick-dev specs |
| `docs/investigations/` | Investigation case files from `/investigate` |

Skills live in `skills/`. See `skills/README.md` for the full flywheel.

---

## Task Tracking Emoji

Use in all `docs/` files for visual skimming:

| Emoji | Meaning |
|-------|---------|
| 🔳 | Not started |
| 🔁 | In progress |
| ✅ | Done |
| ❌ | Cancelled (add inline reason) |

Story files and specs use `[ ]`/`[x]` checkboxes (GitHub renders these interactively).

---

## Critical Rules

<!-- Add project-specific rules here as they emerge.
     Format: rule on one line, why on the next.
     Example:
     - Always use the `db` helper for queries, never raw SQL strings.
       Reason: prevents injection and ensures connection pooling.
-->

---

## Conventions

<!-- Naming, import style, file organization — patterns every file already follows.
     Populated by /discover (brownfield) or emerges from /retrospective over time.
-->

---

## Quiet commands

<!-- The exact build/test invocations to run, with quiet flags, so tool output doesn't sit in
     the conversation for the rest of the session. dev-story / code-review use these verbatim.
     Example:
     - Build + test: `xcodebuild -quiet -scheme App -destination 'platform=iOS Simulator,name=iPhone 17' build test 2>&1 | tee .leanwheel/logs/build-test.log | tail -n 40`
     - One test file: `npx vitest run <file> --reporter=dot`
-->

---

## Known Footguns

<!-- Things that look right but break something.
     Format: what looks right → what actually happens → what to do instead.
-->
