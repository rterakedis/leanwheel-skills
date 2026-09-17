---
type: llm
criteria: "Look ONLY at the `AUTOMATED:` line inside the TESTING PLAN block; ignore every other part of the message, including the MANUAL: line and any prose before or after the block. PASS if that line lists test/flow/eval NAMES or identifiers (e.g. CustomerLimitServiceTests, UpgradeSheetFlow, docs/evals/epic-1.md#E1-01), or is exactly 'none'. FAIL only if it states assertions or steps instead of names."
focus: last_message
---
