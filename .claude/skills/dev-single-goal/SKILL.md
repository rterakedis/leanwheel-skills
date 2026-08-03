---
name: dev-single-goal
description: Implement a single stated goal in any folder — no project docs required. Grills for intent, writes a verifiable plan, executes, and verifies by running. Use when the user states a task/goal in a folder with no leanwheel docs/ tree, or says "single goal", "dev goal", "just do this here", or "one-off task".
---

# Dev Single Goal Skill

**Goal:** Drop into any folder, take one stated goal from intent → grilled requirements → approved verifiable plan → implemented → verified green. Zero doc prerequisites, zero doc obligations.

**When:** Any folder that is *not* a leanwheel project — a coworker's repo, a scripts directory, a fresh clone, an experiment. If `docs/prd.md` **and** `docs/architecture.md` exist, this is a leanwheel project: recommend `/quick-dev` instead (it keeps those docs current — this skill deliberately does not) and proceed here only if the user confirms they want the doc-free lane.

## Activation

Nothing is required to exist. Read what happens to be there, silently skip what isn't:

1. Read `CLAUDE.md` / `AGENTS.md` if present (project conventions override defaults).
2. If `docs/architecture.md` + `docs/prd.md` exist → say the one-line `/quick-dev` recommendation above, then follow the user's choice.
3. Detect the toolchain from files (`*.xcodeproj`/`*.xcworkspace`/`Package.swift`, `package.json`, `pyproject.toml`, `go.mod`, `Makefile`, …) — this drives the Build & Test Gate later. No toolchain is fine; note it.
4. Identify the goal. If the user hasn't stated one, ask: "What should this do — user-facing outcome?"

**Scope check:** single goal = one deliverable (cross-layer work OK if serving one goal). Multi-goal → ask which to do first; each goal is its own run.

## Phase 1 — Grill

**Classify complexity first — it scales everything below:**
- **Stateful / multi-step** — a state machine, multi-step flow, concurrent actions, async lifecycle, or non-trivial failure handling. Gets the full Behavior Contract + Clarification Gate.
- **Simple** — one obvious path (small fix, config, copy, mechanical refactor). Behavior Contract is one line or omitted; the gate is a no-op unless a real fork surfaces. Do not manufacture ceremony.

**Behavior Contract (stateful goals):** before writing any plan, enumerate explicitly — this is the grilling, and it happens *before* the plan exists:
- **Flows:** each user/system flow as a step sequence — happy path plus every alternate path.
- **States & transitions:** valid transitions and the **illegal** ones that must be rejected.
- **Edge cases:** empty/boundary inputs; concurrent or duplicate actions; partial failure and retry/idempotency; offline/timeout; permission/auth edges; first-run vs returning.
- **Expected outcomes:** the observable result for each flow and edge case.
- **Invariants:** what must always hold regardless of path.

**Clarification Gate:** from the enumeration, separate:
- **Stated assumptions** — ambiguities with one sensible default. Record the assumption in the spec and proceed.
- **Material ambiguities** — forks you cannot resolve without guessing at intent (which state wins on conflict? is partial success allowed? what happens on re-entry?). A **proposed new dependency** or **single-caller abstraction** is a material item — confirm it earns its place.

Any material ambiguity → **stop and ask the user**, concisely, and wait. Never write a speculative plan around an unresolved fork. Simple goals with no material ambiguity skip straight to Phase 2 — do not invent questions to satisfy the gate.

## Phase 2 — Plan

Write the spec to `.leanwheel/goals/{slug}.md` using [spec-template.md](spec-template.md). On first use, also write `.leanwheel/goals/.gitignore` containing `*` so the host repo's git status stays clean (same self-ignore pattern as `.leanwheel/sim/`). Rules:

- Intent frozen after approval
- Boundaries (Always / Ask-First / Never) drive implementation
- Behavior Contract section carries the Phase 1 enumeration (stateful goals); recorded assumptions listed
- Tasks are file-level, specific actions
- ACs are Given/When/Then, independently testable; every material edge case from the contract gets its own AC
- Verification section names the exact commands the gate will run

**Get explicit approval before implementing.** The approved spec is the verifiable plan — every AC and verification command in it is checkable after execution.

## Phase 3 — Implement

For each task:
1. Understand file, action, outcome.
2. Apply the simplicity ladder — reuse before rewrite, stdlib/native before a new dependency, least code that satisfies the AC. (Use the fuller `## Simplicity & Anti-Over-Engineering` rules if the host CLAUDE.md carries them.)
3. Implement. Check off `[ ]` → `[x]` in the spec (Tasks and ACs, during — not after).
4. Wrong assumption discovered → update the spec's assumption list, don't silently deviate. If it voids a frozen Intent/Boundary line, that's an Ask-First stop.

**Security pass (conditional):** if the goal touches auth / data-access / api / secrets / llm / payments / file-upload, run the matching categories from `skills/security-review/SKILL.md`. Findings are fixed in-scope or surfaced — there is no deferred-items log here.

## Phase 4 — Build & Test Gate

**Verification is by running, not by reading.** Before the goal is called done, the project must compile clean and its tests must pass this session — by actually invoking the toolchain detected at Activation:

- **Apple / Swift:** `xcodebuild -scheme {scheme} -destination '…' build test` or `swift build && swift test`
- **Web / Node:** `npm run build && npm test` (or the lint/typecheck script if no tests)
- **Python / Go / other:** the project's documented or conventional command (`pytest`, `go build ./... && go test ./...`, `make test`, …)
- **No toolchain:** run the spec's Verification commands if any; otherwise record `Verification: manual-required — {exact command a human should run}` in the spec. Never fake a green result.

**Red build or failing test = not done.** Read the output, fix, re-run until green — or HALT (below). Then:

1. **Invariant verification (stateful goals):** each spec invariant needs **evidence** — a test exercising it or a cited assertion/guard (`file:line`). Record per invariant in the spec: `- [x] {invariant} — {evidence}` or `- [ ] UNVERIFIED: {why}`. No evidence = not a pass; feed it to the review below. Skip for simple goals.
2. If `docs/evals/` happens to exist (leanwheel project, user chose this lane anyway): execute **RUN** from `skills/evals/SKILL.md` — a failing case is a regression, treat like a red build.

## Phase 5 — Inline Review

The diff is the uncommitted changes; the spec is loaded. Run condensed passes:

- **A — Correctness:** logic errors, null derefs, unchecked returns, injection/auth/data exposure, races, error handling.
- **B — Edges & regressions:** boundary checks, error paths, callers outside the diff, unchecked assumptions.
- **C — AC audit:** unimplemented/partial ACs, violated Boundaries, `[ ]` UNVERIFIED invariants.
- **F — Over-engineering:** one tagged line per finding — `delete:` / `stdlib:` / `native:` / `yagni:` / `shrink:`; never flags a smoke test / validation / security / accessibility for removal; end `net: −N lines possible` or `Lean already.`

Auto-patch clear fixes; surface ambiguous ones as questions. **Re-verify green:** if any patch changed code, re-run the Build & Test Gate — a fix verified by reading is not resolved.

## Phase 6 — Wrap Up

1. Set spec `status: done`. Report: what shipped, ACs verified, gate result (command + green), patches applied, anything UNVERIFIED or assumed.
2. **Escalate only on signal, never by default:**
   - Goal spawned real follow-up goals, or the folder is an undocumented codebase the user will keep working in → offer `/discover` (brownfield docs) or `/setup` (full lifecycle). One line, their call.
   - A leanwheel docs/ tree exists and this change contradicts what `architecture.md`/`prd.md` describe → say so explicitly and offer to update them (quick-dev Phase 4 motion). Never silently, never mandatorily.
3. No GitHub tracking, no ledger, no doc phase — those belong to the project lanes.

## HALT Conditions

Stop and report if:
- A material ambiguity surfaces mid-implementation that the gate should have caught
- An Ask-First boundary triggers, or the task requires out-of-scope changes risking breakage
- A required file/dependency is missing and can't be inferred
- The build/tests cannot be made green after a reasonable number of fix attempts — report the failing output; never report done over a red build
