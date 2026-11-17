# Epic Flywheel — Step 5: Rolled-up, deduplicated, subtracted Test Plan

Read at the epic boundary, after gates 1–4c are green. Re-read it then even if read earlier — the epic's run may have compacted context. This is the one model-heavy step this thread does itself, over collected plan text only — never source.

## Contents
- Inputs
- Procedure (steps 0–4)
- Output file template
- After writing

## Inputs
- `docs/epics/.epic-{N}-test-plans.md` — the scratch list stashed in Step 2 of each story: one `## {epic}.{story} — {title}` block with `AUTOMATED: {names}` and `MANUAL: {tagged lines}`. The `AUTOMATED` names are the subtract list.
- `apple_project` (from Activation step 3) — Apple projects split simulator vs physical-device; non-Apple projects get a generic "automated/local-runnable vs manual" split instead.

## Procedure
Read the accumulated `docs/epics/.epic-{N}-test-plans.md` scratch list (collected plan text only — no source). Then:

0. **Every flow opens with a "Starting state" prerequisites block** before step 1 — the required data and settings state the tester must have in place. Steps then follow real usage order, not story order.
   - **Setup commands are part of the starting state.** When reaching the state needs a terminal command (`scripts/sim.sh launch …`, `xcrun simctl …`, a dev-server or seed script), print the exact command in the block.
   - The command carries every flag the app needs to honour it — a launch argument the app only reads in combination with another (e.g. an entitlement override applied only under `--uitest`/`--seed`) must appear with its companions; a bare flag the app silently ignores produces a false finding.
   - When unsure, grep the launch-argument handler (testability foundation) rather than guessing.
1. **Deduplicate & merge** the `MANUAL` items across stories into end-to-end flows (e.g. five stories each touching the cart → one "complete a purchase" flow plus the per-story edge cases that aren't covered by the flow).
2. **Enumerate edge cases** the individual story plans listed, deduped against the flows.
3. **Subtract what is already automated (mandatory, zero-token grep + one judgment pass; DD-31).** For each candidate human step:
   - Collect the union of the stashed `AUTOMATED` names, then grep the project's **UI-test flows**, **unit test target**, and **`docs/evals/epic-*.md`** (cumulative, every epic) for the step's surface or assertion — identifiers, flow/suite/case names, the string asserted on.
   - **Covered** → remove it from the checkbox list. It is listed by name in the flow's `Automated — do not re-test:` line instead.
   - **Not covered** → it stays, unless a test could clearly pin it — then say so in `## Notes` as an automation gap (`/e2e-tests` candidate), and keep it as a human step for this pass only.
   - Record `{s}` = the number of candidate steps subtracted and `{g}` = the number of automation gaps flagged; both go in the boundary report.

   > **Rule: a test plan step that restates an existing automated assertion is a defect of this step.** Section A may contain only (a) assertions with no flow/eval coverage and (b) visual/layout-judgment passes — design-eye, Dynamic Type, dark mode, copy tone. Everything else is either already pinned (subtract it) or should be (flag it).
4. **Classify every remaining test** by where it can run:
   - **Simulator / local-runnable** — anything exercisable in the iOS/iPadOS/macOS simulator (or, for web, a local dev server / headless browser). UI flows, navigation, state, layout, Dynamic Type, light/dark, most logic.
   - **Physical-device-required** — needs real hardware or a paid/org capability: camera & photo capture, real push notifications (APNs on device), Face ID / Touch ID, background location, Bluetooth / NFC / HealthKit sensors, real network conditions, thermal/perf, StoreKit on-device purchase, anything gated behind an **org-based developer account / provisioning** the user doesn't yet have. The stashed `MANUAL` tags (`device-only`, `sandbox-only`) route here directly.

## Output file template
Write the result to `docs/epics/epic-{N}-test-plan.md`:

````markdown
# Epic {N} — {title}: Test Plan
_Rolled up from {X} story plans on {date}: {a} human steps after subtracting {s} already-automated, {b} physical-device._
_To log a finding: add an **indented** plain bullet (`-` or `*`, no checkbox) directly under the relevant step — e.g. `  - shows wrong total`. Leave the `- [ ]` step lines as checkboxes (check them off as you pass them). Then run `/harvest-findings {N}` to capture and schedule the findings._
_If a step turns out to be already covered by a passing test, note it as a finding too (`  - already automated: {flow}`) — it is a plan defect the retro counts._

## A. Simulator / local-runnable (do now)
### Flow: {name}
**Automated — do not re-test:** {flow/suite/eval names that already prove this flow, e.g. `UpgradeSheetFlow`, `CustomerLimitServiceTests`, `E12-03`}
**Starting state:** {required data, settings state — everything that must be true before step 1}
```bash
scripts/sim.sh launch --uitest --seed heavy --route {route}   # every flag the app needs; bare flags are ignored
```
- [ ] {step the automation cannot see} → {expected} [visual-judgment | setup-unreachable]
### Edge cases
- [ ] {case} → {expected}

## B. Physical-device pass (DEFERRED — requires org developer account)
> These cannot run on the current developer account / simulator. Batch them for the
> physical-device test session once the org-based account and provisioning are in place.
- [ ] {test} — requires: {camera | APNs push | Face ID | …}

## Notes
- {anything ambiguous the tester should confirm}
- Automation gaps (should be pinned, `/e2e-tests` candidates): {list or "none"}
````

The `Automated — do not re-test:` line is mandatory on every section-A flow (write `none` only when the flow genuinely has no coverage — and then expect the flow to be an automation gap).

## After writing
- Also **append section B's items to a persistent cross-epic backlog** `docs/testing/physical-device-backlog.md` (create if absent), tagged with the epic.
- Delete the `.epic-{N}-test-plans.md` scratch file after writing.
