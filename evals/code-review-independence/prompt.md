---
name: code-review-independence
tags: [code-review, contract, independence, progressive-disclosure]
runs: 1
max_turns: 25
timeout_seconds: 600
---
Run `/code-review` on story 1.1 in the project in the current working directory, as the independent reviewer. The dev-story REVIEW HANDOFF is: `STORY: docs/epics/1-1-paged-catalog-listing.md`, `BASE: review-base` (a git tag on the commit before the story's work; the work itself is uncommitted). There is no build or test toolchain in this project, so do not try to run one (state that Verify green was skipped for that reason), and skip the ledger, GitHub tracking, and epic-context steps. Do NOT apply any patch or fix-now: leave every finding as an unresolved `[ ]` item, and do not edit any source file. Put the full report, including the scored `RUBRIC:` line and the `FOLLOW-UP REVIEW:` field, in your final message.
