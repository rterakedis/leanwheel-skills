---
name: appstore-preflight-branch-scoped
tags: [appstore-preflight, progressive-disclosure]
runs: 1
max_turns: 45
timeout_seconds: 900
---
Run `/appstore-preflight` on the app project in the current working directory. Skip Step 7b (this is not a first submission's review packet) and do not use the network. Produce the remediation story (if there are findings) and the submission checklist, then the Step 8 report.
