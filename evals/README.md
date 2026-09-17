# Skill evals (for this repo's own skills)

Behavior tests for leanwheel skills, in the `claude plugin eval` layout: one directory per
case with `prompt.md` (frontmatter + the prompt), `graders/*.md` (one grader each), and an
`case.yaml`. Fixtures are tiny synthetic project trees under `fixtures/` — never real project
data. Each run starts in an empty workspace, so every fixture-based case has a `scaffold.sh`
(named in `case.yaml` → `context.scaffold_script`) that copies its fixture in; the runner only
executes it with `--scaffold`. (`context.add_dirs` can't be used for this: it only accepts
read-only directories *inside* the case.)

These are **not shipped by the plugin** (manifest `skills` points at `.claude/skills/`).

## Run

```bash
claude plugin eval . --scaffold --case 'dev-story-*'                       # one case glob
claude plugin eval . --scaffold --runs 1 --allow-tools Bash Write Edit \
  --max-cost-usd 5                                                          # whole suite
claude plugin validate .                            # structure only, free
```

Requires Claude Code **v2.1.269 or later** (`claude --version`; `claude update` to upgrade). Older builds print "`plugin eval` is currently in early access" and run nothing.
Results land in `evals/results/<timestamp>/`, which is gitignored.

## Rule

A skill change that alters a **report field**, a **parsed heading/marker**, or a **gate
outcome** (the contracts in `.claude/skills/CLAUDE.md`'s table) must add or update a case here.
Graders should be deterministic (`regex`, `file_exists`, `tool_used`) wherever the contract
is a shape — to grade a file's contents, use `target: { source: file, path: <path> }`; use `llm` graders only for judgment calls.

## Two traps

Both bit real graders in this suite:

- **`focus: files` / `target: files` is the *list of paths* Claude created, not their contents.** A
  judge pointed at it sees `docs/epics/1-3-post-test-findings.md` and nothing else, so a rubric
  about what's *in* the file can never pass. Use `{ source: file, path: <path> }`.
- **An `llm` grader sees the whole `last_message` unless you scope it.** Say in the criteria which
  field to look at and that everything else is to be ignored, or prose elsewhere in a correct
  report will fail it.

## Shell self-tests

Deterministic scripts are tested by shell, not by `claude plugin eval` — a model call is the
wrong instrument for asserting a parser's behavior. They live in `scripts/test/` and cost
zero tokens:

```bash
bash scripts/test/evals-runner.sh   # scripts/evals.sh against committed fixtures (DD-71)
bash scripts/test/budget.sh         # per-file byte budget ratchet (DD-72)
bash scripts/test/checklist-render.sh  # appstore-preflight checklist rendering (DD-74)
```

## Cases

| Case | Skill | Asserts |
|---|---|---|
| `dev-story-report-shape` | dev-story / lw-story-developer | final report carries `TESTING PLAN` with both `AUTOMATED:` and `MANUAL:` sub-fields, and `MANUAL:` lines carry a why-tag; carries a `REVIEW HANDOFF` with `STORY:` and `BASE:`; emits no `RUBRIC:` (the developer never scores its own diff) |
| `harvest-plan-defect` | harvest-findings | an "already automated" note is captured as `plan-defect` (pre-checked, no story), the visual finding becomes a `tweak`/`bug` AC, and the plan is reset |
| `epic-boundary-subtract` | epic-flywheel (step 5) | a rolled-up plan never re-lists a step covered by a flow/eval; every section-A flow opens with `Automated — do not re-test:` and a full-flag setup command |
| `appstore-connect-metadata-scoped` | appstore-connect | a METADATA run reads `op-metadata.md` and never `op-assets.md` / `op-products.md` (Read or shell); writes a ≤ 100-char, space-free `keywords.txt`; ends with the `METADATA:` return line |
| `appstore-connect-products-diff` | appstore-connect | IMPORT seeds `products.md` marking the code-only product; DIFF emits `PRODUCTS DIFF: n mismatches, m recommendations` naming it; `op-assets.md` stays unread |
| `appstore-preflight-branch-scoped` | appstore-preflight | on a StoreKit-but-no-CloudKit project: `checks-storekit.md` read, `checks-cloudkit.md` and the checklist template never read, `render-checklist.sh` run; the written checklist keeps the IAP section, drops the CloudKit line, and carries no unresolved markers |

The `appstore-*` cases use Bash, Write, and Edit, and read files by name — run them with those tools granted:

```bash
claude plugin eval . --scaffold --case 'appstore-*' --runs 1 --allow-tools Bash Write Edit --max-cost-usd 5
```

`tool_used` graders assert which skill files were read (`input_match` is a regex over the tool input, so it matches the file name wherever the plugin is installed); `min: 0, max: 0` asserts a file was **not** read — the progressive-disclosure claim itself.

Planned next: code-review independence on a git fixture (finds a planted bug in an *untracked* file; reads the story only up to `## Dev Agent Record` before the passes); dev-story red-build → HALT (not `review`); epic-flywheel HALT on a failing
cumulative eval; harvest-findings idempotent re-run; migration-shape fail-first ordering.
