---
name: evals
description: Composable eval operations — a persistent, stack-agnostic regression net plus optional LM-judge scoring. Called by create-story (BUILD), dev-story and code-review (RUN/SCORE). Directly invocable as /evals to run the current eval set. Works for Swift, web, and Python alike.
---

# Evals Skill

**Goal:** Give the flywheel the *non-deterministic* half of verification the
Build & Test Gate can't cover, and a **persistent regression net** so a later
story can't silently revert an earlier story's behavior — the exact failure mode
that motivated the Build & Test Gate, now made cumulative.

**Token philosophy (Pro plan):** the default eval type is `command` — a shell
command with an expected result. **Zero model tokens.** It works identically for
`swift test`, `xcodebuild`, `pytest`, `npm test`, `playwright`, or `curl`. The
`judge` type (LM-as-judge) is **opt-in and token-flagged** — used only where
behavior is genuinely non-deterministic and no command can assert it.

---

## Eval set layout

```
docs/evals/
  README.md         ← format reference (scaffolded by /setup)
  epic-{n}.md       ← accumulated cases for epic n, one block per case
  e2e-{area}.md     ← retro-fit cases registered by /e2e-tests (backfill net)
```

Each case is a fenced block:

```
### EVAL {epic}.{story}-{seq} — {short title}
type: command            # command | judge
origin: story {epic}.{story} AC{n}   # provenance
enabled: true
run: swift test --filter CartTotalTests     # command type only
expect: exit-0                               # exit-0 | output-contains:"<s>" | output-matches:/<re>/
# judge type only:
# target: git diff -- Sources/Cart.swift     # what the judge reads
# rubric: |
#   - Empty cart returns 0, never nil
#   - Discounts never produce a negative total
```

Cases are **append-only** and live beyond their origin story. `command` cases are
the regression net; `judge` cases are reserved for trajectory/quality checks.

---

## Operations

### BUILD — derive cases from a story (called by create-story / dev-story)

Input: a story file path (and its `{epic}.{story}`).

1. Read the story's **Acceptance Criteria** and, if present, the `### Behavior
   Contract` invariants and enumerated edge cases.
2. For each AC / invariant that maps to a **deterministic, runnable** check, append
   a `type: command` case to `docs/evals/epic-{epic}.md`:
   - Prefer the project's existing test command with a filter to the new test(s)
     (`swift test --filter X`, `pytest -k x`, `npm test -- -t "x"`, `go test -run X`).
   - **Exception — runners that boot a Simulator** (`xcodebuild … test`): use the
     **same unfiltered suite command** for every case, with a per-case
     `output-contains:` needle on the test/suite name. RUN batches identical
     commands into one launch; per-case filtered invocations cost one Simulator
     launch each and exhaust it on a long run.
   - If the AC is an HTTP/CLI behavior, a `curl`/CLI invocation with
     `output-contains:` is fine.
   - `expect: exit-0` unless a specific output assertion is needed.
2b. **A case that enumerates must assert it enumerated.** If the check walks a
   source tree, globs files, or greps the codebase, the underlying test must
   assert a plausible lower bound on what it found — `expect: output-contains:"X"`
   over a walk that produced no output is a gate that cannot fail. Also pick the
   needle so it can only match the intended target: a generic summary line
   (`output-contains:"Test run with"`) matches whichever target printed first and
   passes while the target you care about is red.
3. Only when an AC is **inherently non-deterministic** (LLM output quality, "reads
   naturally", visual judgment not covered by design-verify) add a `type: judge`
   case — and note in your report that it carries per-run token cost.
4. Do **not** invent tests that don't exist yet. A case must reference a check that
   the dev-story implementation will actually create. If the test doesn't exist
   yet, write the case `enabled: false` with a `# pending: <test to write>` note;
   dev-story flips it to `true` once the test lands.

Report: `N command cases, M judge cases appended to docs/evals/epic-{epic}.md`.

### RUN — execute the regression net (called by dev-story Build & Test Gate, code-review Verify-green, or `/evals`)

1. Resolve scope: a single epic file, or all of `docs/evals/` (default for `/evals`).
2. Collect the `enabled: true` `type: command` cases and **group by identical
   `run:` command**. Execute each distinct command **once**, capture combined
   output + exit code, then check every case in the group against that single
   result. Never one invocation per case — on Apple projects that means one
   `xcodebuild … test` Simulator launch per case, and 50+ sequential launches
   exhausts the Simulator; one launch scores the whole group. Genuinely distinct
   commands still run separately. Record pass/fail **per case** and the failing
   line on failure. **Zero tokens** — this is just running commands.
   **Empty output fails.** An `output-contains:` / `output-matches:` case whose
   command produced no stdout is a **fail** (`empty output — gate cannot
   discriminate`), regardless of exit code — the mechanical form of "a gate that
   enumerates must assert it enumerated": a walk/glob/grep that found nothing
   must not pass vacuously.
3. For each `enabled: true` `type: judge` case **only if judging is requested**
   (the caller passes `judge=true`, or the user runs `/evals --judge`): read
   `target:`, score against `rubric:`, pass if all rubric points hold. Skipped by
   default to protect the token budget — report skipped judge cases as `(judge: skipped)`.
4. A failing `command` case is a **regression**: surface it exactly like a red
   Build & Test Gate — the caller must fix and re-run or HALT, never proceed over red.

Report: `RUN epic {n}: {p}/{t} command pass, {j} judge {pass|skipped}. Regressions: <list or none>`.

### SCORE — emit the rubric line (called by code-review)

Code-review already runs its adversarial passes; SCORE just turns that into a
**structured pass/fail line per dimension** — no extra model calls. Dimensions:
`correctness`, `edge-cases`, `ac-coverage`, `design` (n/a if non-UI), `security`
(n/a if not flagged). GATE = PASS only if every applicable dimension is PASS.
Append the line to the story's `### Review Findings` and to the metrics ledger.

---

## Notes

- The eval set is **versioned with the project** (it's in `docs/`), reviewed like
  code — matching the paper's "set the bar at the eval, not the demo."
- `command` cases make the regression net **cumulative and cheap**; that is the
  single highest-leverage, lowest-cost eval mechanism for a Pro-plan workflow.
- Keep `judge` cases rare. Each one is a recurring token cost on every RUN --judge.
