---
name: epic-boundary-subtract
tags: [epic-flywheel, test-plan, contract]
runs: 1
max_turns: 15
---
You are the epic-flywheel orchestrator at Epic 1's boundary for the sampleapp fixture. Execute ONLY step 5 (rolled-up, deduplicated, subtracted test plan) from the epic-flywheel skill. The stashed per-story plans are:

## 1.1 — Customer limit service
AUTOMATED: CustomerLimitServiceTests, E1-01
MANUAL:
  - Tap Add on the 6th customer → upgrade sheet appears [setup-unreachable]
  - Limit copy reads right in dark mode [visual-judgment]

## 1.2 — Upgrade sheet
AUTOMATED: UpgradeSheetFlow
MANUAL:
  - Tap Add on the 6th customer → upgrade sheet appears [setup-unreachable]
  - Restore Purchases with a sandbox account [sandbox-only]
  - Price line at Dynamic Type XL doesn't truncate [visual-judgment]

Write docs/epics/epic-1-test-plan-new.md (use that filename so the fixture's existing plan is untouched). Grep the fixture's SampleAppUITests and docs/evals as the skill says.
