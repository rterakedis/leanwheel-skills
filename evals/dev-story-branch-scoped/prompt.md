---
name: dev-story-branch-scoped
tags: [dev-story, progressive-disclosure, contract]
runs: 1
max_turns: 20
timeout_seconds: 600
---
Run `/dev-story docs/epics/1-1-slugify-helper.md` in the project in the current working directory. You are running directly in this session, not as a subagent. To keep the run cheap: assume Activation already recorded the review base ref `4f1c2ab`, that implementation is done, and that the Build & Test Gate is green (`bash test/slugify_test.sh` passed; the automated test is `slugify_test.sh`). Do not run any build, test, git, or script command, and do not call the Agent tool; reading and listing files is fine. Follow the skill's Activation and On Completion steps as written, including any files it tells you to read for this project and story, then give the completion report with its TESTING PLAN and REVIEW HANDOFF blocks. Where the skill would spawn the reviewer, just print the REVIEW HANDOFF block instead.
