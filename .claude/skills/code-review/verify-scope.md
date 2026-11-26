# Verify green on Swift / Apple projects — prove the log or re-run in proportion

Read at Step 5 → **Verify green** when `docs/setup/swift/` exists (or an `.xcodeproj` / `Package.swift` is present). Other stacks keep the full re-run in SKILL.md.

**Why.** A whole verification cycle on an app with an XCUITest plan costs about an hour, and re-running it here re-proves code nobody changed since the developer's green run. The flywheel runs the full cycle **once**, on the tree merged with main, right before the PR (`skills/story-flywheel/final-cycle.md`, DD-84). That cycle is the safety net; your runs cover only what *you* changed. What does not change: you never report green from reasoning alone. Either a log provably applies to this tree, or you run something.

**Cost accepted:** a regression outside the suites you re-run surfaces in the final cycle, not here, and is slower to trace. Do not re-run the full plan "to be safe" — that restores the hour this rule removes.

## 1. Prove the author's log (always, patches or not)

From the `REVIEW HANDOFF`: `LOG` and `LOG TREE`. All three must hold:

1. **Complete and unfiltered.** The log's own command line carries no `-only-testing` / `-skip-testing` / filter, and every expected test target reports an executed count. A project log scorer (`## Quiet commands`) → run it on the file; only its green token counts.
2. **Green.** No failure line; the scorer's token, when there is one. A green-looking tail is not evidence (`docs/setup/swift/simulator.md` → *A green-looking log is not a green run*).
3. **Still applies.** No source file changed after it was produced:
   ```bash
   git add -A && git diff --name-only {LOG TREE} "$(git write-tree)"   # paths changed since the log
   ```
   Changes confined to the story file, `docs/`, or other files no build or test reads → the log applies. No `LOG TREE` → fall back to modification times: `find . -newer {LOG} -type f -not -path './.git/*' -not -path './.leanwheel/*'`, same filter.

All three hold → record `RELIED ON: {LOG} @ {LOG TREE} — full plan green` and do not re-run it.
Any one fails, or `LOG: none` → the log proves nothing: run one full plan yourself, and record a `patch` finding against the verification record (the handoff claimed a log that does not apply).

## 2. Re-run what your patches touch

- **No patch or fix-now changed code** → nothing more to run; step 1 is the verification.
- **Patches changed code** → run the unit suite plus the suites and UI flows those patches touch (`-only-testing:`; log to `.leanwheel/logs/targeted.log`). A patch to shared test infrastructure or a bootstrap path touches every flow — then run the full plan.
- **Evals:** only the cases your patches added or touch (`bash scripts/evals.sh --case {id} --quiet`). The epic RUN belongs to the final cycle.
- **String Catalog CHECK:** only if a patch added, removed, or edited a user-facing string or a translator comment, or the Dev Agent Record shows the author's `CATALOG:` was `unavailable`. Otherwise skip, stating which — the final cycle runs CHECK on the merged tree unconditionally.
- **Sabotage** for every test or eval case you wrote is unchanged (SKILL.md) — it is one targeted run and the cheapest proof there is.

**Standalone review** (no flywheel will run a final cycle after you): run String Catalog CHECK unconditionally, and say in the report that the story's final cycle is still owed.

## 3. Follow-up pass (you were given a `PATCH BASE`)

Read `git diff {PATCH BASE}` only. Re-run the suites that diff touches and nothing else; rely on the previous reviewer's `RAN` for the rest and on the final cycle for the whole.

## 4. Raise what the final cycle needs

Judge from the diff, independently of the author: does it touch layout, navigation, or the root view (`matrix=full`)? A launch argument or DEBUG-only code (`release-guard=yes`)? Report `FINAL CYCLE NEEDS` — the orchestrator takes the higher of yours and the author's, so you can only raise it.

Pinned counts: a patch never hand-edits one (`final-cycle.md` → *Pinned counts*); a hand-edited pin in the author's diff is a MEDIUM `patch` finding.
