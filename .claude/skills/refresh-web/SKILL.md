---
name: refresh-web
description: Research current web platform, CSS, Astro, and Hugo best practices from gold-standard sources and update the docs/setup/web/ reference files and the modern-web.md guardrails stub. Use when the user says "refresh web", "update web guidance", "refresh css", "refresh astro", or "refresh hugo".
---

# Refresh Web Best Practices Skill

**Goal:** Research the current state of the web platform (HTML/CSS/JS), Astro, Hugo, accessibility, and SEO from primary sources and update the sectioned reference docs in `docs/setup/web/` plus the `modern-web.md` guardrails stub in the skills repo. These files are baked into every new web project — keeping them current is critical for guiding correct choices.

**Scope:** **Baseline widely-available** web platform features only (supported in all major engines for 30+ months), plus the current stable major of Astro and Hugo. **Hard exclude** experimental flags, origin trials, single-engine features, and pre-release framework APIs. When in doubt, omit.

---

## Step 1 — Locate Files

```bash
# Project's working copies (these are what get updated in use)
ls docs/setup/web/

# Skills repo stub originals (also update these so new projects get current content)
find . -path "*/setup/stubs/web/*.md" | sort
find . -path "*/setup/stubs/modern-web.md"
```

Read every file completely before proceeding — treat the current content as the baseline.

If `docs/setup/web/` does not exist, ask whether the user wants to run `/setup` first or update just the stubs in the skills repo.

---

## Step 2 — Research Current Best Practices

Use WebSearch and WebFetch to pull current content from the gold-standard sources below. For each finding, note Baseline status (or framework version) where the pattern was introduced or changed.

### Gold-Standard Sources

- **web.dev** — web.dev (Chrome team; Baseline status, CWV guidance)
- **MDN** — developer.mozilla.org (canonical platform reference + Baseline badges)
- **Astro Docs & Blog** — docs.astro.build, astro.build/blog (release notes)
- **Hugo Docs & Release Notes** — gohugo.io/documentation, github.com/gohugoio/hugo/releases
- **CSS-Tricks** — css-tricks.com (modern CSS patterns)
- **Smashing Magazine** — smashingmagazine.com (a11y, CSS architecture)
- **WAI / W3C** — w3.org/WAI (WCAG updates, ARIA Authoring Practices)

### Research by Target File

For each: compare findings against the existing file content; note what is still accurate, what is outdated, and what is missing.

**`css-design-system.md`**
- New Baseline CSS since the last update (functions, selectors, at-rules)?
- `light-dark()`, container queries, `:has()`, nesting — any guidance changes?
- New CSS-replaces-JS capabilities (scroll-driven animations, anchor positioning) reaching Baseline?
- Core Web Vitals metric or threshold changes?

**`astro.md`**
- New stable Astro major? Breaking changes to content collections, `astro:assets`, directives?
- New rendering features (server islands, actions) and whether they belong in a *static-site* guidance doc
- Config or integration changes (`@astrojs/sitemap`, `@astrojs/rss`)

**`hugo.md`**
- Template system changes (the 0.146 rework superseded `_default/` — anything further)?
- Asset pipeline function renames/deprecations (`css.Sass`, `js.Build`)
- Image processing and render hook changes

**`accessibility-seo.md`**
- WCAG version/criteria changes; ARIA APG updates
- Search engine requirements changes (structured data types, meta handling)

**`anti-patterns.md`**
- New patterns AI tools commonly generate that should be added to the rejection list?
- Any anti-patterns now acceptable because the platform changed (document the reason)?

---

## Step 3 — Write Updated Files

For each file with changes:

1. Update `docs/setup/web/{file}.md` with current content.
2. Update the corresponding stub at `{skills_path}/.claude/skills/setup/stubs/web/{file}.md` so new projects get the same content.
3. Update the `> Updated: {today's date} — {scope label}` line at the top of each changed file.

### Formatting Rules (preserve these exactly)

- `#` title, then `> Updated:` line, then one-line scope note
- `##` section headers
- Fenced code blocks with `✅` correct and `❌` rejected patterns side-by-side
- Tables for comparison/decision content
- No conversational filler — declarative, RFC-style tone

### Guardrails Block (`modern-web.md`)

After updating the sectioned files, review the guardrails stub. Update it only if:
- A pattern was added to or removed from the hard-rejection table (document removals)
- The quick reference table has a new row
- A checklist item changed

The guardrails file must stay under ~50 lines — it lives in CLAUDE.md and is loaded every turn.

---

## Step 4 — Report to User

1. **What changed:** Bullet list per file — new patterns added, outdated patterns removed, Baseline/version bumps.
2. **What stayed the same:** Brief confirmation that still-valid content was preserved.
3. **Sources consulted:** Which gold-standard sources had relevant current content.
4. **Reminder:** Existing projects with `docs/setup/web/` get their copies updated by this run; projects that haven't run `/setup` yet get the updated stubs when they do.

---

## Step 5 — Offer Audit Handoff

After reporting, ask:

> "Guidance updated. Run `/web-audit` now to check the current site against the new patterns? (y/n)"

If yes: invoke `/web-audit` immediately. If no: stop.
