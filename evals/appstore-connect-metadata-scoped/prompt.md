---
name: appstore-connect-metadata-scoped
tags: [appstore-connect, progressive-disclosure]
runs: 1
max_turns: 25
timeout_seconds: 600
---
In the storeapp fixture, run `/appstore-connect metadata` for locale en-US. Draft the listing copy from docs/project/brief.md. There is no preflight checklist and no user to ask: use the brief's support and privacy URLs, and skip `review_information/`. Run the lint with `--no-network`. Finish with the op's return line.
