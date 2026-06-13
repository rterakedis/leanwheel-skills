## Web Guardrails (Baseline CSS / Astro 5+ / Hugo 0.146+)

> Updated: 2026-06-12

Full reference patterns live in `docs/setup/web/`. This section contains only the always-active hard rules.

### Hard Rejections — Never Use in New Code

| Banned | Replacement |
|---|---|
| `<div onclick>` / non-semantic interactive elements | `<button>`, `<a href>`, semantic landmarks |
| JS accordion / modal / tooltip / sticky / smooth-scroll | `<details>`, `<dialog>`, `popover`, `position: sticky`, `scroll-behavior` |
| Inline `style=""` or raw hex/px where a token exists | `var(--token)` from `docs/ux/DESIGN.md` token layer |
| `!important` (except 3rd-party override w/ comment) | Flat single-class selectors |
| `client:load` on static content (Astro) | No directive — render static; justify every `client:*` |
| Raw `<img>` for local assets | `astro:assets` `<Image />` / Hugo page resources + render hook |
| jQuery, Moment.js, Bootstrap, icon-font CDNs | Native DOM, `Intl`, CSS Grid, inline SVG |
| Remote fonts (Google Fonts etc.) / any third-party CDN on critical path | System font stack; self-hosted same-origin subsetted woff2 if brand-justified |
| New styles dumped into one global `main.css` | Small shared core (≤30 KB) + page/component-scoped CSS |
| `px` font sizes; `user-scalable=no` | `rem` + `clamp()` fluid scale |
| Absolute positioning / fixed heights for layout | Grid / flex + `gap`; `min-height` |
| Hardcoded site URLs in templates/markdown | `relref`/`relURL` (Hugo), `Astro.site`-derived |
| Runtime `fetch()` of build-time content | Content collections / `.GetPage` |
| Class-based dark mode token forks | `color-scheme` + `light-dark()` |

### Quick Reference

| Situation | Use |
|---|---|
| Color/spacing/radius/type value | CSS custom property token, declared once on `:root` |
| Dark mode pair | `light-dark(#light, #dark)` |
| Component adapts to its container | Container query (`@container`) |
| Page adapts to viewport | Media query in `rem` |
| Sibling spacing | `gap` |
| Heading sizes | `clamp()` fluid scale, `rem` |
| Fonts | `system-ui` stack by default; custom = self-hosted subsetted woff2, `font-display: optional` + preload, metric-matched fallback — no visible swap |
| Interactivity on a static site | `<script>` tag / native HTML first; framework island only with justification |

### Pre-Implementation Checklist

Before marking any story done, verify:
- [ ] No inline styles; no raw values where tokens exist; light + dark both rendered
- [ ] Semantic elements: one `<h1>`, no skipped heading levels, buttons are `<button>`
- [ ] Every image: optimized via the SSG pipeline, `alt`, explicit dimensions
- [ ] Every page: unique `<title>`, meta description, canonical, OG tags
- [ ] Keyboard: focus visible everywhere, no `outline: none` without replacement
- [ ] Zero unjustified `client:*` directives / no JS where HTML+CSS suffices
- [ ] Zero third-party origins: no CDN fonts/scripts/styles; LCP element not lazy-loaded
- [ ] Animation gated behind `prefers-reduced-motion: no-preference`

> Full patterns, code examples, and SSG guidance: `docs/setup/web/`
