---
name: forge-idea
description: Alias for /ideate, kept so the /forge-idea slash command still works. The adversarial pressure-test of an idea now runs inside the ideate skill.
---

# Forge Idea (alias)

This skill's flow moved into `/ideate` (`skills/ideate/SKILL.md`), which runs the same
adversarial cross-examination through the `elicit` engine's Pressure mode and records
outcomes to the decision log instead of a `forged-idea-{slug}.md` file.

Invoke `/ideate` now, telling it the user wants the current idea pressure-tested. Do not
follow any remembered version of this skill's old flow or write a `forged-idea` artifact.
