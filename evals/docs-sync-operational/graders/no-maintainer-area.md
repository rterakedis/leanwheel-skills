---
type: file_exists
path: docs/maintainer/*
exists: false
---
The Dockerfile change is a deploy signal, but `docs/maintainer/` does not exist: the skill must stay silent rather than create a top-level area directory (hard rule; that is `/setup`'s job).
