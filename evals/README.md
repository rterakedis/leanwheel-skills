# Skill evals (for this repo's own skills)

Behavior tests for leanwheel skills, in the `claude plugin eval` layout: one directory per
case with `prompt.md` (frontmatter + the prompt), `graders/*.md` (one grader each), and an
optional `case.yaml` (context: fixture dirs). Fixtures are tiny synthetic project trees under
`fixtures/` — never real project data.

These are **not shipped by the plugin** (manifest `skills` points at `.claude/skills/`).

## Run

```bash
claude plugin eval . --case 'dev-story-*'          # one case glob
claude plugin eval . --runs 1 --max-cost-usd 2      # whole suite, cheap
claude plugin validate .                            # structure only, free
```

Early-access feature: first-party clients pick it up after `claude update` + a fresh session.
Results land in `evals/results/<timestamp>/`, which is gitignored.

## Rule

A skill change that alters a **report field**, a **parsed heading/marker**, or a **gate
outcome** (the contracts in `.claude/skills/CLAUDE.md`'s table) must add or update a case here.
Graders should be deterministic (`regex`, `file_exists`, `tool_used`) wherever the contract
is a shape; use `llm` graders only for judgment calls.

## Cases

| Case | Skill | Asserts |
|---|---|---|
| `dev-story-report-shape` | dev-story / lw-story-developer | final report carries `TESTING PLAN` with both `AUTOMATED:` and `MANUAL:` sub-fields, and `MANUAL:` lines carry a why-tag |
| `harvest-plan-defect` | harvest-findings | an "already automated" note is captured as `plan-defect` (pre-checked, no story), the visual finding becomes a `tweak`/`bug` AC, and the plan is reset |
| `epic-boundary-subtract` | epic-flywheel (step 5) | a rolled-up plan never re-lists a step covered by a flow/eval; every section-A flow opens with `Automated — do not re-test:` and a full-flag setup command |

Planned next: dev-story red-build → HALT (not `review`); epic-flywheel HALT on a failing
cumulative eval; harvest-findings idempotent re-run; migration-shape fail-first ordering.
