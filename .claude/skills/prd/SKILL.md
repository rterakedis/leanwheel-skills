---
name: prd
description: Alias for /spec with target prd, kept so the /prd slash command still works. The PRD create, update, and validate flow lives in the spec skill.
---

# PRD (alias)

This skill's create/update/validate flows moved to `/spec` with target `prd`
(`skills/spec/SKILL.md`), which renders `docs/prd.md` from the decision log and
`spec/prd-template.md`.

Invoke `/spec` with target `prd` now and follow it. If there is no decision log and no
existing PRD, the idea isn't settled yet — invoke `/ideate` first. Do not follow any
remembered version of this skill's old flow.
