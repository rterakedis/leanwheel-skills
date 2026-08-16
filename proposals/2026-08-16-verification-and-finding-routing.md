# Proposal — Verification integrity and finding routing

> **Status:** proposal, unimplemented. Written 2026-08-16 from the YardPath Epic 11 retrospective.
> **Origin:** 14-story epic (YardPath, Swift/SwiftUI + Core Data), run end-to-end through
> `/epic-flywheel` → `/harvest-findings` → `/story-flywheel`.
> **Author's note:** every claim below is backed by something that actually happened in that epic,
> cited inline. Where a change is speculative rather than evidenced, it says so.

Two failure classes dominated the epic. Neither was project-specific, and neither was caused by a
person being careless — in both cases the **framework only offered doors that led there**.

1. **Gates that could not fail.** Five distinct instances in one epic. A test, eval, or verification
   command that reports green while checking nothing is worse than no gate, because it is trusted.
2. **Binary finding-routing.** `code-review` offers exactly two dispositions, `[Patch]` and
   `[Defer]`. A finding that is trivially fixable but outside the story's ACs has no door except
   deferral. YardPath's open deferred items went **13 → 27** during this epic.

Six changes follow, ordered by expected value. Each names the skill and section to change.

---

## 1. Add a `[Fix-Now]` disposition — `code-review`, `deferred`

**Problem.** `code-review` classifies findings as `[Patch]` (in-scope, auto-apply) or `[Defer]`
(log it, schedule it later). There is no disposition for *"this is four lines, adjacent to the diff,
and obviously right."* Such findings default to `[Defer]` because deferring is cheap at the moment
of discovery — logging costs thirty seconds, while fixing risks the story's green gate and widens
its diff. The process actively teaches this: overloaded stories get split (YardPath split two
mid-epic for exactly that), so expanding scope is the punished behavior.

**Evidence.** YardPath Epic 11 created 31 deferred items and resolved 17 of them, net **+14 open**;
the open backlog more than doubled (13 → 27). Meanwhile *four* real fixes shipped in the same epic
**outside any story** — an invalid SF Symbol, a zombie-row guard, a notification-scoping fix, and a
build-setting exclusion. None was an AC. Each happened only because the human in the loop said "fix
it now." Without that human, all four would have become deferred items. The disposition set was the
binding constraint, not judgment.

**Proposed change.** Add a third disposition to `code-review`'s triage, with an explicit ceiling so
it cannot become a scope-creep loophole:

> **`[Fix-Now]`** — apply immediately without an AC, when **all** of:
> - the change is small (suggested default: ≤ ~10 lines, one file) and adjacent to the diff already under review;
> - it is provably safe — covered by an existing test, or accompanied by one written in the same pass;
> - it introduces no new dependency, schema change, public API change, or user-visible copy change;
> - it can be described in one line in the commit message.
>
> Anything failing a condition is `[Defer]`, unchanged. Record `[Fix-Now]` items in the story's
> Review Findings so they are reviewable, not invisible.

**Also update `deferred`** so its intake explicitly rejects items meeting the `[Fix-Now]` bar,
rather than accepting anything handed to it. The log's value is proportional to its signal.

**Effort:** small — a disposition definition plus a paragraph in each skill's triage section.

---

## 2. Require a discriminating check on every new gate — `dev-story`, `code-review`

**Problem.** Nothing in any skill requires demonstrating that a newly written test, eval, or
assertion can *fail*. A green gate is accepted as evidence of correctness when it may be evidence
of nothing.

**Evidence (five instances, one epic).**

| Instance | How it presented |
|---|---|
| 7 eval cases | `expect: output-contains:"Test run with"` matched the *unit* target's summary line even when the UI target was red |
| 8 more eval cases | Asserted a Swift Testing *type* name; the runner prints the `@Suite("display name")`. Red-by-construction — could never pass |
| `sim.sh flow <Name>` | The harness appends `Flow` to the class name; a mismatched name ran **nothing** and reported **green** |
| `simctl log stream` grep | Measured a channel that did not carry the signal; reported 0 warnings with the bug present *and* absent |
| `xcodebuild test` grep | Same, second attempt, same false zero |

The first two were found only because someone went looking. The third and fourth were found only
because a sabotage run was attempted.

**Proposed change.** Add to `dev-story`'s Build & Test Gate and `code-review`'s verification step:

> **A new gate is not done until it has been shown to fail.** Before claiming a test, eval, or
> assertion passes, break the thing it guards — revert the fix, reintroduce the defect, or corrupt
> the input — and confirm the gate fails **and names the specific item**. Restore, confirm green.
> A gate that has only ever been observed green is unverified, regardless of how many times it ran.

Record the discriminating check in the story's Completion Notes so a reviewer can see it happened.

**Effort:** small to write, meaningful in run time. Worth scoping to *new* gates, not every run.

---

## 3. Make source-walking gates fail when they find nothing — `evals`, `dev-story`

**Problem.** A gate that enumerates things (files, symbols, literals, properties) and asserts a
property of each passes **vacuously** when enumeration returns zero. This is a distinct failure from
#2: the gate is genuinely discriminating on the items it finds, but silently finds none — a moved
directory, a changed path, a `#file`-relative walk that broke.

**Evidence.** YardPath's `SFSymbolValidityTests` walks the source tree for SF Symbol literals. It
asserts `literals.count > 50` before checking validity, specifically so a broken walk fails loudly.
When the same pattern was reused for a 61-property Core Data audit, the reviewer deliberately
corrupted the parser to confirm the count guard fired — it did. Without that assertion both gates
would have reported green while checking nothing.

**Proposed change.** Add to `evals` (case authoring) and `dev-story` (test authoring):

> **Any gate that enumerates must assert it enumerated.** A test or eval that walks a source tree,
> globs files, or greps a codebase must assert a plausible lower bound on what it found, and fail
> if the count is implausible. `expect: output-contains:"X"` over a walk that produced no output is
> a gate that cannot fail.

**Effort:** trivial — one assertion per gate, plus the guidance.

---

## 4. Validate the measurement channel before trusting a zero — `dev-story`

**Problem.** "I grepped for the error and found none" is treated as evidence of absence. It is only
evidence if the channel carries the signal.

**Evidence.** A SwiftUI runtime warning was assumed to reach stderr. Two verification attempts —
`simctl log stream` and `xcodebuild test` output — both reported **0 occurrences**, and both were
blind: a sabotage run with the bug reintroduced *also* reported 0. The correct channel turned out to
be an os_log fault in `com.apple.runtime-issues`, the inverse of the assumption. It was established
only by a **positive control**: deliberately triggering the warning produced 25 hits on log-stream
and 0 on the stderr pty in the same run. Two commit messages had by then recorded the wrong fact.

**Proposed change.** Add to `dev-story`'s verification guidance:

> **Before accepting a zero as proof, prove the channel can see a one.** When verification takes the
> form "search output for X and find none," first produce an X deliberately and confirm it appears
> on the channel being searched. An unvalidated zero is not evidence of absence.

**Effort:** trivial to state; costs one deliberate reproduction per novel channel. Only needed when
the channel is new or assumed — not for ordinary test output.

---

## 5. Write the guard test first on migration-shaped stories — `create-story`, `dev-story`

**Problem.** For a wide mechanical change (rename across N call sites, type migration across N
properties, dependency swap), the durable deliverable is the *invariant test*, not the N edits.
Written afterward, it is authored against already-corrected code and can only be shown to pass.

**Evidence.** YardPath's 61-property Core Data optionality migration sequenced it deliberately:
write the pinning test first, confirm it fails naming **all 61** mismatches, then fix, then re-prove
at the end by reverting exactly one property and confirming a **named** failure. Both directions
were reproduced independently at review. The 61 edits are a one-time cost; the test is what stops a
fourth recurrence — the same class had already shipped three times.

**Proposed change.** Add to `create-story` (story shaping) and `dev-story` (task ordering):

> **When a story's core is a repeated mechanical change, the invariant test is Task 1.** Write it
> before the edits, confirm it fails and enumerates every violation, then fix. Re-prove at the end
> by reverting exactly one instance. A test written after the sweep can only be shown to pass.

Consider a story-shape label (`migration`) so `create-story` can apply this ordering automatically.

**Effort:** small — task-ordering guidance, no new machinery.

---

## 6. Fold remediation ACs back into the test plan — `harvest-findings`

**Problem.** `harvest-findings` Step 4 strips the tester's inline findings so the plan is
re-runnable. Nothing adds verification steps for what the resulting remediation story *fixed*. The
loop is asymmetric: testing's output is removed, remediation's output is never added. A re-test
therefore exercises the original surfaces and never confirms the fixes landed.

**Evidence.** YardPath's Story 11.13 shipped seven fixes. Three had **no** step in the reset plan —
a new Summary period control, arbitrary service-price entry, and a mileage-PDF two-line wrap. One
(a new DEBUG affordance) made it in only because that story's dev happened to update a flow's
starting state by hand. Caught by the owner asking why a stale-looking note had survived the reset.

**Proposed change.** Extend Step 4:

> After stripping harvested findings, **add one verification step per AC of the remediation story**,
> placed under the flow whose finding produced it. The plan must be able to prove the remediation
> worked, not merely re-run the original pass. Where an AC changed a surface the plan describes
> (a starting state, a setup note), update that text too.

This is the only change here with an existing hole rather than an absent feature — the skill already
owns the plan's lifecycle; it just does half of it.

**Effort:** small — one step, mechanical (the ACs are already enumerated in the story file).

---

## Also worth considering (lower confidence)

**A retrospective lens for "half-rules."** YardPath's Core Data convention required every attribute
be optional *in the model* and said nothing about the generated Swift property — so following the
rule exactly created the precondition for a crash that shipped three times. The generalizable
technique is auditing your own conventions for rules that establish a precondition without
addressing its consequence. Plausibly a `retrospective` prompt; offered tentatively because it rests
on a single instance.

---

## Deliberately not proposed

These were YardPath-specific and are recorded in that project, not here:

- Core Data model-vs-generated-property optionality (→ its `CLAUDE.md`)
- Money display-vs-selection predicate split (→ its `architecture.md`)
- Simulator harness quirks — `sim.sh flow` name mangling, `content_size` device-state leakage,
  `@SceneStorage` inheritance across tests (→ its `docs/maintainer/`)
- Concurrent-session discipline. The rule ("never run two sessions in the primary working tree")
  already exists and is correct; it was **violated**, by two sessions including the flywheel's own.
  Worth noting only because the flywheel skills structurally pull work toward the primary tree — the
  epic-boundary merge lands on `main` and the human builds there. If that pull is judged to be the
  cause rather than the occasion, it becomes a framework concern; on one instance, it is not yet.

---

## Suggested order

1 and 6 are the highest value per unit of effort: **1** removes the pressure that grows the deferred
log, **6** closes an outright hole. **2** and **3** are the epic's dominant failure class and are
cheap to state. **4** is narrow but prevented a genuinely wrong conclusion from shipping. **5** is
the most situational.
