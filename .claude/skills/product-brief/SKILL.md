---
name: product-brief
description: Alias kept so the /product-brief slash command still works. Idea formation and brainstorming live in the ideate skill, and writing docs/project/brief.md lives in /spec with target brief.
---

# Product Brief (alias)

This skill's flows moved: brainstorming and idea formation live in `/ideate`
(`skills/ideate/SKILL.md`); writing `docs/project/brief.md` lives in `/spec` with target
`brief` (`skills/spec/SKILL.md`).

Invoke `/ideate` now and follow it — it records decisions to the decision log and hands off
to `/spec brief` when the idea is settled. If the idea is already fully settled and the user
only wants the brief written, invoke `/spec` with target `brief` instead. Do not follow any
remembered version of this skill's old diverge/distill flow.
