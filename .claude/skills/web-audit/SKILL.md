---
name: web-audit
description: Audit planning docs, story files, templates, styles, and markup against the web guidance in docs/setup/web/ and the design tokens in docs/ux/DESIGN.md. Produces a remediation story file with one AC per finding. Use when the user says "web audit", "audit web", "audit site", or "check web patterns".
---

# Web Audit Skill

**Goal:** Scan the entire project — planning docs, story files, templates, stylesheets, and markup — against the guidance in `docs/setup/web/` and the design tokens in `docs/ux/DESIGN.md`. Collate all findings into a single remediation story file that `/dev-story` can implement directly.

**Requires:** `docs/setup/web/` must exist. If absent, tell the user to run `/setup` (for a new project) or `/refresh-web` (to populate an existing project's web docs).

---

## Step 1 — Load Guidance

```bash
ls docs/setup/web/
ls docs/ux/DESIGN.md 2>/dev/null
```

Read each guidance file completely. Pay particular attention to `anti-patterns.md` — it contains the hard rejection list used for code scanning. If `docs/ux/DESIGN.md` exists, read its frontmatter token block — raw values in stylesheets are measured against it.

---

## Step 2 — Inventory the Project

```bash
# Planning docs
ls docs/prd.md docs/architecture.md docs/epics.md 2>/dev/null

# Story files
find docs/epics -name "*.md" | sort

# Detect SSG / web framework
ls astro.config.* hugo.toml config.toml package.json 2>/dev/null

# Source surface (exclude build output and dependencies)
find . \( -name "*.astro" -o -name "*.html" -o -name "*.css" -o -name "*.scss" \) \
  ! -path "*/node_modules/*" ! -path "*/dist/*" ! -path "*/public/*" ! -path "*/resources/*" \
  | sort

# Hugo templates if applicable
find layouts assets -type f 2>/dev/null | sort

# Existing audit files (avoid re-auditing completed work)
find docs/maintainer -name "web-audit-*.md" 2>/dev/null | sort
```

Note which framework is in play — Astro checks only run on Astro projects, Hugo checks only on Hugo projects. If no source files exist yet, skip Step 4 and note "no source to audit" in the report.

---

## Step 3 — Audit Planning Docs

### `docs/architecture.md`

| What to check | Rejection signal |
|---|---|
| Styling approach | Prescribes inline styles, CSS-in-JS for a static site, Bootstrap, or no token layer |
| Interactivity design | Prescribes a framework runtime / SPA patterns for content pages |
| Content strategy | Prescribes runtime fetching of build-time content; markdown outside collections (Astro) |
| Asset handling | Prescribes `public/`/`static/` for images that should use the pipeline |
| Accessibility | No WCAG 2.2 AA floor stated for a user-facing web product |

### `docs/prd.md`

| What to check | Rejection signal |
|---|---|
| Non-functional requirements | No performance budget (CWV) for a content site; mandates a JS framework where static rendering serves the FRs |

### `docs/epics.md` and story files (excluding `web-audit-*.md`)

- Tasks that instruct adding `client:load`, jQuery, Bootstrap, icon-font CDNs, or JS for native HTML/CSS behavior
- Dev Notes prescribing raw `<img>`, inline styles, or hardcoded URLs
- ACs that imply banned patterns ("the modal library must…")

---

## Step 4 — Audit Source Code

Run greps appropriate to the detected framework. Record file path and line number for each hit.

```bash
EXC='--exclude-dir=node_modules --exclude-dir=dist --exclude-dir=public --exclude-dir=resources'

# Inline styles in markup
grep -rn 'style="' --include="*.astro" --include="*.html" $EXC .

# !important escalation
grep -rn '!important' --include="*.css" --include="*.scss" --include="*.astro" $EXC .

# px font sizes
grep -rn 'font-size:\s*[0-9.]*px' --include="*.css" --include="*.scss" --include="*.astro" $EXC .

# Non-semantic interactivity
grep -rn '<div[^>]*onclick\|<span[^>]*onclick\|role="button"' --include="*.astro" --include="*.html" $EXC .

# Legacy libraries
grep -rn 'jquery\|moment\.js\|font-awesome\|bootstrap' --include="*.astro" --include="*.html" --include="package.json" $EXC .

# Focus suppression
grep -rn 'outline:\s*none\|outline:\s*0' --include="*.css" --include="*.scss" --include="*.astro" $EXC .

# Astro only: hydration directives + raw img
grep -rn 'client:load\|client:only\|client:idle\|client:visible' --include="*.astro" $EXC .
grep -rn '<img ' --include="*.astro" $EXC .

# Hugo only: hardcoded URLs, static-path images, raw HTML in content
grep -rn 'https\?://' layouts/ 2>/dev/null
grep -rn '/images/\|static/' layouts/ content/ 2>/dev/null | grep -v "render-"
grep -rln '<div\|<script' content/ 2>/dev/null

# Missing alt attributes
grep -rn '<img\([^>]*\)>' --include="*.astro" --include="*.html" $EXC . | grep -v 'alt='
```

**Token compliance (if `docs/ux/DESIGN.md` exists):** grep stylesheets for raw hex colors (`#[0-9a-fA-F]{3,8}`) outside the `:root` token declaration block. Each raw value that duplicates or approximates an existing token is a finding; values with no corresponding token are a DESIGN.md gap finding.

**Judgment pass:** For each `client:*` hit, read the component — only flag if the component has no genuine interactivity. For each `<img>` hit in Astro, only flag local assets (external URLs are fine). Do not flag intentional, commented compatibility shims.

**Page-level checks:** Open the base layout(s) and verify: single `<h1>` pattern, meta description required (not defaulted), canonical present, `lang` attribute set, OG tags present. Each missing item is one finding.

---

## Step 5 — Triage Findings

**Scope tags:** `[DOC-ARCH]` `[DOC-PRD]` `[DOC-EPICS]` `[STORY]` `[CODE]`

**Severity:**
- `HIGH` — accessibility failure (keyboard/focus/alt/contrast), SEO-blocking gap (missing title/description/canonical), unjustified framework runtime on content pages, runtime fetching of build content
- `MEDIUM` — off-token values, raw `<img>` on local assets, `!important`, legacy library usage, hardcoded URLs
- `LOW` — style/convention gaps (nesting depth, missing `partialCached`, px media queries)

Deduplicate: many instances of the same pattern in one file = one finding noting the count.

If zero findings across all scopes: report "Clean — no violations found against current guidance." and stop.

---

## Step 6 — Write Remediation Story

Write to `docs/maintainer/web-audit-{YYYY-MM-DD}.md`. Create `docs/maintainer/` if it does not exist. Use the same story format as `/swift-audit`:

```markdown
---
Status: ready-for-dev
Type: remediation
Generated: {today's date}
---

# Web Audit Remediation — {today's date}

**Source:** `/web-audit` run against guidance in `docs/setup/web/` (+ `docs/ux/DESIGN.md` tokens)
**Findings:** {N} total — {H} HIGH / {M} MEDIUM / {L} LOW

## Acceptance Criteria

### Planning Docs
- [ ] [HIGH][DOC-ARCH] {one-line description} — `docs/architecture.md`

### Story Files
- [ ] [MEDIUM][STORY] {one-line description} — `docs/epics/{filename}.md`

### Source
- [ ] [HIGH][CODE] {one-line description} — `{file}:{line}`

## Tasks

### 1. Update Planning Docs
- [ ] Revise docs to replace banned patterns with current guidance

### 2. Update Story Files
- [ ] Update story Dev Notes and tasks that prescribe banned patterns

### 3. Fix Source
- [ ] Resolve all HIGH findings before any MEDIUM/LOW
- [ ] Rebuild the site after each batch and verify no template/build errors

## Dev Notes

### Reference
Read all files in `docs/setup/web/` before implementing any fix. The guidance files are
the source of truth for what each banned pattern should be replaced with.

### Finding Details
{Per finding: what was found verbatim (1–3 line snippet), file:line, the replacement pattern from guidance}

### Notes
- Do not modify story files listed here if their Status is `in-progress` or `done`.
- Token findings: if a raw value has no matching token, add the token to `docs/ux/DESIGN.md`
  first, then reference it — do not invent token names ad hoc.
```

---

## Step 7 — Report to User

1. State the story file path.
2. Print the finding summary table (scope × severity, as in `/swift-audit`).
3. Say: "Run `/dev-story docs/maintainer/web-audit-{date}.md` to implement all fixes."
