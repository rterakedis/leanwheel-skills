# CSS & Design System Rules

> Updated: 2026-06-12 — Baseline widely-available CSS
> Design tokens, color scheme handling, fluid type, and modern layout. Applies to all web surfaces (apps and SSG sites).

---

## Design Tokens as Custom Properties

All colors, spacing, radii, and type sizes come from `docs/ux/DESIGN.md` frontmatter and are declared once as CSS custom properties on `:root`. Components consume tokens — they never declare raw values.

```css
/* ✅ Single token layer, mapped 1:1 from DESIGN.md */
:root {
  --color-primary: #2b6cb0;
  --color-surface-base: #ffffff;
  --space-1: 0.25rem;
  --space-4: 1rem;
  --radius-md: 0.5rem;
}

.card {
  background: var(--color-surface-base);
  padding: var(--space-4);
  border-radius: var(--radius-md);
}
```

```css
/* ❌ Raw values scattered through components */
.card {
  background: #fff;
  padding: 17px;
  border-radius: 7px;
}
```

If a needed value has no token, that is a DESIGN.md gap — add the token (and update DESIGN.md), don't inline the value.

---

## Color Scheme: Light and Dark

Declare support once, then use `light-dark()` for every token with a light/dark pair. Never fork entire stylesheets per scheme.

```css
/* ✅ */
:root {
  color-scheme: light dark;
  --color-surface-base: light-dark(#ffffff, #111418);
  --color-text: light-dark(#1a202c, #e2e8f0);
}
```

```css
/* ❌ Duplicate token blocks under a class toggle as the primary mechanism */
.dark-mode .card { background: #111418; }
```

A manual theme toggle, if the product needs one, sets `color-scheme` on `:root` — it does not introduce a parallel class-based token system.

---

## Typography

- Root font size stays at the browser default. All type sizes in `rem`. **Never `px` for font-size.**
- Fluid scale with `clamp()` for headings: `font-size: clamp(1.5rem, 1.2rem + 1.5vw, 2.25rem);`
- Body line-height is unitless (`1.5`–`1.7`). Reading measure constrained to `45–75ch` (`max-width: 65ch` on prose containers).

### Fonts: System First, Self-Hosted Only

**Default is the system font stack** — zero bytes, zero swap, zero layout shift:

```css
/* ✅ The default for every new project */
:root {
  --font-body: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  --font-mono: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
}
```

A custom font is a deliberate brand decision that must be justified in `docs/ux/DESIGN.md` typography rationale. When justified:

- **Self-hosted on the same origin as the site — no exceptions.** Fonts live in the site's own asset pipeline as subsetted woff2. Google Fonts, Adobe Fonts, any font CDN, or `@import url(https://...)` is a **hard rejection** (performance: extra origin on the critical path; privacy: leaks visitor IPs to a third party).
- Max 2 families, max ~4 weight/style files total; variable font preferred over multiple static weights.

**No visible font swap — ever.** A mid-read glyph flash or reflow when the font arrives is a defect, not a trade-off. Two failure modes, two mandatory fixes:

1. **`font-display: optional` is the default** (not `swap`). Either the font makes first paint (it will on most visits — see below) or the page stays on the fallback for this view and uses the cached font from the next navigation on. The font never pops in mid-read. `font-display: swap` is allowed only as a documented DESIGN.md exception, only for headings — body text never swaps after paint.
2. **Metric-matched fallback is mandatory** regardless of strategy, so any fallback rendering occupies identical space (use a generator — e.g. fontaine or Capsize — rather than eyeballing the overrides):

```css
@font-face {
  font-family: "Brand";
  src: url("/fonts/brand-var.woff2") format("woff2");
  font-display: optional;
}
@font-face {
  font-family: "Brand-fallback";
  src: local("Arial");
  size-adjust: 105%; ascent-override: 92%; descent-override: 24%; line-gap-override: 0%;
}
/* --font-body: "Brand", "Brand-fallback", system-ui, sans-serif; */
```

Make the font win its ~100ms block window so `optional` shows the brand font on first paint, not just repeat visits: `<link rel="preload" as="font" type="font/woff2" crossorigin>` in `<head>`, subset aggressively (latin-only is typically 70–90% smaller), and keep the file on the same origin (no extra connection setup). A preloaded same-origin subsetted woff2 routinely beats the window; a 300 KB full-unicode font from a CDN never will.

---

## Layout Decisions

| Scenario | Use |
|---|---|
| Page-level scaffolding (header / main / sidebar / footer) | CSS Grid (`grid-template-areas`) |
| One-dimensional rows of items (toolbar, tag list, nav) | Flexbox + `gap` |
| Responsive card grid | `grid-template-columns: repeat(auto-fill, minmax(min(100%, 18rem), 1fr))` — no media queries needed |
| Component that adapts to its container (card in sidebar vs main) | Container queries (`container-type: inline-size` + `@container`) |
| Page layout that adapts to viewport | Media queries (`@media (width >= 64rem)`) |
| Spacing between siblings | `gap` — **never** margin hacks on children |
| Centering | `display: grid; place-items: center` or flex — never absolute + transform |

---

## Modern CSS Replaces JavaScript

Before writing JS for a UI behavior, check this table. Each row is a rejection in review if implemented in JS.

| Behavior | Use instead of JS |
|---|---|
| Accordion / disclosure | `<details>` + `<summary>` |
| Modal dialog | `<dialog>` + `showModal()` (the one-line JS open call is fine) |
| Tooltip / dropdown panel | `popover` attribute + `popovertarget` |
| Smooth scrolling | `scroll-behavior: smooth` |
| Sticky header | `position: sticky` |
| Carousel snap points | `scroll-snap-type` / `scroll-snap-align` |
| Lazy-loading images | `loading="lazy"` attribute |
| Parent styling based on child state | `:has()` |
| Simple show/hide on checkbox/radio state | `:checked` + sibling selectors |
| Animating element entry | `@starting-style` + `transition` |

---

## Stylesheet Architecture: Lean CSS

Two layers — a page never downloads CSS for components it doesn't render:

| Layer | Contains | Delivery |
|---|---|---|
| **Shared core** (one small file) | Token layer (`:root`), modern reset, base element styles, reusable classes used on **3+ page types** (`.prose`, `.card`, `.btn`, nav/footer) | Cached site-wide. Budget: **≤ 30 KB minified**; if ≤ ~10 KB, inline it in `<head>` and skip the request entirely |
| **Page/component CSS** | Formatting specific to one page type or component | Scoped with the page: Astro scoped `<style>` blocks; Hugo per-template resources concatenated via Pipes for that template only |

Rules:
- The shared core is **not** a dumping ground. New page-specific styles go in the page layer; a class is promoted to core only once a third page type needs it (and gets a token review on the way in).
- One ever-growing `main.css` that every page loads is the anti-pattern — but so is a separate request per page that defeats caching. Small cached core + scoped page CSS is the balance.
- No CSS frameworks (Bootstrap, full Tailwind via CDN) on content sites; the token layer + a few utilities is the design system.
- One source of truth per component's styles — co-locate, never spread across files.

## Selectors & Structure

- Use native CSS nesting; keep nesting ≤ 2 levels deep.
- Specificity stays flat: single class selectors. No ID selectors for styling, no `!important` (see anti-patterns).
- Respect user preferences: wrap all non-essential animation in `@media (prefers-reduced-motion: no-preference)`.

---

## Performance Floor

Target: **PageSpeed/Lighthouse 100** and Core Web Vitals green (LCP < 2.5s, CLS < 0.1, INP < 200ms) on a mid-range phone, not a dev laptop. The mechanics:

- **Zero third-party origins on the critical path.** No CDN fonts, scripts, or styles — self-host everything through the site's asset pipeline. Analytics, if any: lightweight, `defer`/async or server-side; never a tag manager on a content site.
- No layout-shifting media: every `<img>`/`<video>` has `width`/`height` (or `aspect-ratio`).
- The LCP element (usually the hero image or heading) is **never** lazy-loaded; preload the LCP image with `fetchpriority="high"`.
- One stylesheet request (or zero, when the core is inlined) for above-the-fold rendering; no `@import` chains; minify + fingerprint via the SSG pipeline.
- Animate only `transform` and `opacity`; never `top/left/width/height`.
