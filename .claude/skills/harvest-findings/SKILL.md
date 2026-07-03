---
name: harvest-findings
description: Composable operation that harvests inline manual-test findings from an epic's test plan, captures them to the backlog, and turns in-scope ones into a remediation story. Called at the manual-test-pass boundary by /epic-flywheel and /retrospective. Directly invocable as /harvest-findings {N}.
---

# Harvest Findings (Composable)

After an epic's **manual test pass**, the tester records findings as inline bulleted sub-lists directly under the scenarios/steps in `docs/epics/epic-{N}-test-plan.md` (the file `/epic-flywheel` generates at its boundary). This skill harvests those inline findings, captures them durably in the backlog, and triages each by **kind** (bug / tweak / enhancement / question) and **disposition** (in-scope / defer). A finding is **not** assumed to be a bug — it may be a small tweak, an enhancement idea, or a question. The corrective (bug/tweak) in-scope findings become a new remediation story that flows through the normal flywheel; enhancements are scheduled as backlog candidates (never remediation ACs); questions are surfaced for a decision.

**Iron rule — done stories are immutable.** This skill **never** reopens or edits a `status: done` story. Fixes for findings always land in a *new* story `{N}.{last+1}`, never by amending completed work.

**Token posture (Pro plan):** Steps 1–2 and 4 are cheap file parses/edits. The only model work is triage (Step 2) and the create-story call (Step 3, delegated). Idempotent — re-running for the same test-pass date does not duplicate anything.

Directly invocable: `/harvest-findings {N}` — harvest Epic {N}'s test plan. Also called as a composable step by `/epic-flywheel` (after the manual test pass) and `/retrospective` (before the deferred sweep).

**Compose, don't reimplement.** This skill orchestrates existing skills:
- `skills/deferred/SKILL.md` — **LOG-AND-SCHEDULE** for deferred findings and all enhancements.
- `skills/create-story/SKILL.md` — authoring the remediation story file.
- `skills/github-tracking/SKILL.md` — opening the tracking issue.
- `skills/docs-sync/SKILL.md` — **OPERATIONAL** reconcile of the human guides (referenced in the story's DoD).

---

## Activation

1. **Resolve the epic.** Accept `/harvest-findings {N}`; if no number given, infer the most recently completed epic (latest `docs/epics/epic-{N}-test-plan.md`). Require the test plan to exist:
   ```bash
   test -f docs/epics/epic-{N}-test-plan.md || echo "no test plan"
   ```
   If absent, report "No test plan for Epic {N} — run /epic-flywheel to its boundary first" and stop.

---

## Step 1 — Harvest (read-only parse)

Parse `docs/epics/epic-{N}-test-plan.md`. It has scenario/flow headings (`### Flow: {name}`, `### Edge cases`) whose steps and cases are **always top-level `- [ ]` checkbox lines** (`- [ ] {step} → {expected}`). That gives a deterministic finding rule — no marker to remember:

> **A finding is any *indented* bullet nested beneath a step/case line that is NOT itself a `- [ ]` checkbox.**

Concretely:
- **Generated content** = a checkbox item at any depth (`- [ ] …` / `- [x] …`, `-` or `*`). The tester checking a step off (`- [x]`) is *not* a finding — it's the generated step, passed.
- **A finding** = an indented sub-bullet the tester added under a step, opened with a plain bullet marker and **no checkbox**: `-` or `*` (either accepted), e.g. `  - shows wrong total` or `  * ❌ crashes when offline`. An optional leading `❌`/`⚠️` or `FINDING:` is fine but not required — the nesting + no-checkbox is what identifies it.
- **A finding is not necessarily a bug.** It's whatever the tester noted while exercising the step — a defect, a small tweak ("tighten this spacing", "reword this label"), an enhancement idea ("would be nice if it remembered the last filter"), or a question ("is this the intended copy?"). Harvest them all verbatim; the *kind* is classified in Step 2, which decides where each one lands.
- **Multi-line findings:** a finding's text runs until the next bullet or a dedent to a step/heading; fold continuation lines into the one `finding-text`.

Regex intuition (not a literal grep — depth matters): a line matching `^\s+[-*]\s+(?!\[[ xX]\])\S` sitting under a `^[-*]\s+\[[ xX]\]` step is a finding.

Collect a normalized list, one entry per finding:
`{scenario-id, scenario-title, finding-text}` — where `scenario-id` is a stable anchor (the flow/edge-case heading text, plus the step it hangs under if any).

**If no inline findings are found:** report `No test findings to harvest.` and stop. (This is the common, green case — zero cost beyond the parse.)

---

## Step 2 — Capture to `docs/epics.md` FIRST (durability before authoring)

**Before creating any story**, write the harvested + triaged findings back into `docs/epics.md` under the Epic {N} section. This guarantees the findings are captured in the canonical backlog even if a later step fails, and gives Step 3 a stable source to read from.

**Triage each finding on two axes** — *kind* (what it is) and *disposition* (when it's addressed). Kind drives where it lands (Step 3); disposition drives whether it's now or later.

**Kind:**
- **bug** — delivered behavior is broken or wrong vs. what the epic set out to do.
- **tweak** — delivered behavior is basically right but needs a small adjustment (copy, spacing, wording, minor UX). A correction *within* the epic's existing scope.
- **enhancement** — a genuinely new capability or scope beyond what this epic delivered. Not a fix — a new idea surfaced during testing.
- **question** — an ambiguity or product decision the tester couldn't resolve; needs a human answer before it can be actioned.

**Disposition:**
- **[in-scope]** — address in *this* epic (before it's considered done).
- **[defer]** — later work.

> Guidance: `bug` and `tweak` are *corrective* — they fix/adjust what the epic shipped, so an in-scope one belongs in the remediation story. `enhancement` is *additive* — never force it into a remediation story as an AC (that's scope creep mislabeled as a fix); it's routed as a backlog candidate / product decision regardless of disposition. `question` is never auto-storied — it's surfaced for the user to answer. (See Step 3 routing.)

Append a checklisted block under the Epic {N} heading (idempotent — see below):

```markdown
### Epic {N} — Post-Test Findings (harvested {date})
- [ ] {finding-text} — _{scenario-title}_ — **bug** · **[in-scope]**
- [ ] {finding-text} — _{scenario-title}_ — **tweak** · **[in-scope]**
- [ ] {finding-text} — _{scenario-title}_ — **enhancement** · **[defer]**
- [ ] {finding-text} — _{scenario-title}_ — **question** · needs decision
```

**Idempotency (required):** the block is keyed by `(Epic {N}, harvested {date})`. Before writing, check for an existing `### Epic {N} — Post-Test Findings (harvested {date})` heading for the same date. If present, **merge** — add only findings whose `finding-text` is not already listed; never duplicate the block or an existing row. A re-run on a different date creates a new dated block (a distinct test pass).

Use today's date (`date +%Y-%m-%d`).

---

## Step 3 — Route each finding by kind

Routing is driven by *kind* first, then *disposition*:

| Kind | in-scope | defer |
|---|---|---|
| **bug** / **tweak** (corrective) | → AC in the remediation story (below) | → `deferred`/LOG-AND-SCHEDULE (item 5) |
| **enhancement** (additive) | → **not** a remediation AC — treat as a backlog candidate: `deferred`/LOG-AND-SCHEDULE, and if it's material scope, flag it for a product decision (`/correct-course` or `/prd update`) in the output | → `deferred`/LOG-AND-SCHEDULE |
| **question** | → surface to the user for an answer; do **not** auto-create a story. Leave its epics.md row `needs decision` until answered, then re-triage | (same) |

So the **remediation story holds only corrective (bug/tweak) `[in-scope]` findings.** Everything else is scheduled or surfaced, never silently converted into remediation ACs.

Author the story **only if there is ≥1 corrective (bug/tweak) `[in-scope]` finding.**

1. **Determine the story number.** Read `docs/epics.md`; the new story is `{N}.{last+1}` where `last` is the highest existing story number in Epic {N}.

2. **Author the story via create-story.** Invoke `skills/create-story/SKILL.md` to generate `docs/epics/{N}-{last+1}-post-test-findings.md` with:
   - **One acceptance criterion per corrective in-scope finding**, each in Given/When/Then form and each **linking back to its source scenario** (e.g. "_(source: Flow: Checkout → step 'apply promo code')_"). Phrase the AC to the finding's kind — a `bug` AC asserts the *correct* behavior; a `tweak` AC asserts the *adjusted* state ("label reads 'X'", "spacing is 16pt").
   - Title: `Post-test corrections — Epic {N}`; marked `*(remediation)*`.
   - Dev Notes citing the test plan and the harvested block in `docs/epics.md` as the origin.
   - `status: ready-for-dev` in frontmatter (the pinned format).
   - **Definition of Done additions** (write these explicitly into the story so dev-story enforces them at close):
     - [ ] Reconcile `docs/architecture.md`, `docs/prd.md`, and `docs/ux/*` for any behavior these changes affect (via `docs-sync` **OPERATIONAL** — spawn `bmad-docs-sync`, Haiku).
     - [ ] Reset `docs/epics/epic-{N}-test-plan.md` (Step 4 below) so the plan is clean for the next re-test pass.

3. **Append the story row to `docs/epics.md`** under Epic {N}'s stories and bump the epic's story count (mirror the `deferred` skill's new-story entry format). Do this **before** the tracking step so the milestone/issue is filed against a story that exists in the backlog.

4. **Create the tracking issue under Epic {N}'s milestone — required.** The new story must be tracked exactly like any other, so its status flows `ready-for-dev → in-progress → review → done` as `/dev-story` and `/code-review` run on it. `create-story`'s own **GitHub Tracking** step (invoked in item 2) already does this: **ENSURE-MILESTONE** for Epic {N}, then — finding no pre-existing issue for `{N}.{last+1}` (this story was never written to `backlog` by `/epics`) — **CREATE-ISSUE** at `ready-for-dev` and write `github_issue: {number}` back to the frontmatter.

   **Do not double-create.** If create-story's tracking already ran, only **verify** here: `grep '^github_issue:' docs/epics/{N}-{last+1}-post-test-findings.md` is non-zero and the issue sits under Epic {N}'s milestone (`gh issue view {N} --json milestone,labels`). If create-story skipped tracking (older variant) or `github_issue:` is still `0`, run **ENSURE-MILESTONE** + **CREATE-ISSUE** from `skills/github-tracking/SKILL.md` yourself now. Skip silently only if `gh` is unavailable — then note it in the output so the user knows the story is untracked until `/github-tracking backfill`.

   > A remediation story goes straight to `ready-for-dev` (not `backlog`) because it's actionable immediately — consistent with how the `deferred` skill schedules new remediation stories. From here the status lifecycle is automatic: the flywheels and `gh-track.sh` drive the label transitions off the `github_issue:` frontmatter, and `/code-review` closes the issue when the story is done.

5. **Schedule / surface everything not in the remediation story.** For each finding routed away from the story per the table above, call **LOG-AND-SCHEDULE** from `skills/deferred/SKILL.md` (`title` = short summary, `detail` = finding-text, `source` = `docs/epics/epic-{N}-test-plan.md` scenario). This covers: every `[defer]` bug/tweak, and **every `enhancement`** (both dispositions — an enhancement is backlog work, not remediation). It slots each into an existing backlog story or a new remediation/feature story — **never** into the post-test-corrections story. Capture the returned D-IDs.
   - For any **enhancement** that is material new scope, also add a one-line flag in the output recommending `/correct-course` or `/prd update` so it gets a deliberate product decision rather than quietly entering the backlog.
   - For any **question**, do **not** schedule — list it in the output as "needs decision" so the user answers it; leave its epics.md row marked `needs decision`. Once answered, re-run harvest or hand-triage it into bug/tweak/enhancement.

If there is **no corrective (bug/tweak) `[in-scope]`** finding, skip story authoring entirely — everything was deferred, additive, or a question, and is already routed/surfaced in item 5 — and still proceed to Step 4.

---

## Step 4 — Reset the test plan

Remove the **harvested inline finding bullets** from `docs/epics/epic-{N}-test-plan.md` — leave the scenarios, flows, steps, and the physical-device section fully intact. The plan must be clean and re-runnable for the next test pass; only the tester's finding annotations come out (they now live durably in `docs/epics.md` and the story).

This reset is also listed in the remediation story's DoD (Step 3.2) — running it here keeps the plan clean immediately; the DoD item is the backstop ensuring it happened before the story closes.

---

## Output

Report one line, broken out by kind:

```
Epic {N}: {n} findings harvested — {c} corrective in-scope → story {N}.{last+1} (issue #{issue});
{s} scheduled ({D-ids}, incl. {e} enhancements); {q} questions need a decision. Test plan reset.
```

If any enhancement is material new scope, add: `Recommend /correct-course for: {short list}.`
If there are questions, list them so the user can answer.

Zero cases: `No test findings to harvest.` (Step 1 empty), or `{n} findings harvested — 0 corrective in-scope; {s} scheduled ({D-ids}); {q} questions. No remediation story needed. Test plan reset.` (nothing corrective).

---

## Callers

- **`/epic-flywheel`** — at the manual-test-pass boundary: after the user works through `docs/epics/epic-{N}-test-plan.md`, run `/harvest-findings {N}` to capture what they found before the retrospective / next epic.
- **`/retrospective`** — before the deferred sweep, offer `/harvest-findings {N}` so test findings are captured and scheduled alongside the retro's other bookkeeping.
