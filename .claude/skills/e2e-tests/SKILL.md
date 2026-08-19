---
name: e2e-tests
description: Generate automated API/E2E tests for features that already exist — brownfield code, features shipped before the eval net, or manual test-plan scenarios worth automating. Use when the user says "generate e2e tests", "backfill tests", "automate the test plan", or "qa tests for {feature}".
---

# E2E Test Generation Skill

**Goal:** Retro-fit an automated regression net onto already-built features.
All story-scoped testing in this workflow is forward-looking — `evals` BUILD
derives cases from ACs *as stories are written*. This skill covers everything
that shipped without that coverage: brownfield projects onboarded via
`/discover`, features built before `docs/evals/` existed, and manual test-plan
scenarios that a machine could run instead of a human.

**Not this skill:** code review (`/code-review`), story-scoped test authoring
(`/dev-story` writes those), visual verification (`/design-verify`).

**Token posture:** one authoring session; every generated test is registered as
a `type: command` eval case — zero model tokens on every future RUN, forever.

---

## Step 1 — Detect the test framework

Use what the project already has — never introduce a parallel framework:

- **Swift/Apple:** existing XCTest / Swift Testing targets (`Package.swift`
  test targets, `.xctest` schemes); UI flows use **XCUITest**. Read
  `docs/setup/swift/testing.md` if present for project conventions.
- **Web:** `package.json` dev-dependencies (playwright, cypress, vitest,
  jest); existing `tests/` or `e2e/` dirs for patterns.
- **Python:** pytest config; **API-only:** `curl`-based checks are acceptable.

If no framework exists, propose the stack standard (XCTest/XCUITest for Swift,
Playwright for web UI, pytest for Python, vitest+supertest for Node APIs) and
**confirm with the user before adding any dependency**.

## Step 2 — Choose targets

Three input modes; ask which (or infer from how the skill was invoked):

1. **Named feature** — user said "tests for {feature}"; scope to it.
2. **Test-plan conversion** — read `docs/epics/epic-{N}-test-plan.md` and list
   the *simulator/local-runnable* scenarios not yet automated. This is the
   highest-value mode: each converted scenario permanently shrinks the manual
   test pass.
3. **Coverage sweep** — map source modules/screens/endpoints against existing
   test files; present a ranked gap list (user-facing flows and data-mutating
   endpoints first).

Present the chosen scope as a short list and confirm before writing anything.

## Step 3 — Generate API tests (where applicable)

For each in-scope endpoint/service: happy path + 1–2 critical error cases,
status codes, response structure. Follow existing test-file patterns exactly
(naming, fixtures, assertion style).

## Step 4 — Generate E2E/UI tests (where applicable)

- Test complete user workflows, not implementation internals.
- **Semantic locators only** — accessibility identifiers on Swift (add them to
  the source views if missing — that's a legitimate part of this skill's
  diff), roles/labels/text on web. Never brittle coordinate or CSS-path
  selectors.
- Assert visible outcomes; keep tests linear and simple.
- **Apple projects: generated UI tests are *flows*.** This skill is where flows
  get authored. Follow `docs/setup/swift/simulator.md` exactly — file location
  (`{App}UITests/Flows/{Feature}Flow.swift`), naming (so `sim.sh flow {Feature}`
  runs it), the `launch(seed:route:)` / `step(_:_:)` helpers, and the rule that
  state is reached via `--seed` plus a deep-link route, never by tapping through
  setup. Don't invent a parallel convention. If an Apple project lacks the
  testability foundation, propose adding it first (it's the single
  highest-leverage piece of this skill's diff).
- **Web/Python:** reach state via the project's own fixtures/seeding, never by
  driving setup UI.
- No complex fixture composition, no abstractions the project doesn't already
  use.

## Step 5 — Run to green

Run the generated tests with the project's real command (`xcodebuild … test`,
`swift test`, `npx playwright test`, `pytest`). Fix failures immediately.
**Never leave a red generated test in the tree** — fix it or delete it. If a
failure reveals a real product bug, do not "fix" the test to match the bug:
report it, and route it through `/deferred` LOG-AND-SCHEDULE or a remediation
story.

## Step 6 — Register as evals

If `docs/evals/` exists, append one `type: command` case per generated suite
to `docs/evals/e2e-{area}.md` (same case format as `epic-{n}.md`; use
`origin: e2e-tests {date}` and a filtered run command, e.g.
`swift test --filter CheckoutFlowUITests`). These join the cumulative
regression net that `/dev-story`, `/code-review`, and the epic boundary gate
already run.

For every case converted from a test-plan scenario (mode 2), **remove** that
step from section A of `docs/epics/epic-{N}-test-plan.md` and append the
flow/eval name to its flow's `**Automated — do not re-test:**` line (add the
line if absent) — the same subtract rule `epic-flywheel` step 5 applies at the
boundary. Do not leave the step as a checkbox with an `[automated → EVAL {id}]`
suffix: a tester still reads and re-runs a tagged checkbox, which is exactly
the waste the plan is meant to prevent.

## Step 7 — Summary

```
E2E BACKFILL: {n} test files generated ({api}/{ui}) — all green
Coverage: {covered}/{total} in-scope features
Evals registered: {m} cases → docs/evals/e2e-{area}.md
Test plan: {k} scenarios automated (manual pass shrunk by {k})
Gaps remaining: {list or none}
Bugs surfaced: {list or none — routed to deferred/remediation}
```
