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
- Load at most 2 font families; use `font-display: swap` and preload the primary woff2.

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

## Selectors & Structure

- Use native CSS nesting; keep nesting ≤ 2 levels deep.
- Specificity stays flat: single class selectors. No ID selectors for styling, no `!important` (see anti-patterns).
- One source of truth per component's styles — co-locate (component file or one stylesheet section), never spread across files.
- Respect user preferences: wrap all non-essential animation in `@media (prefers-reduced-motion: no-preference)`.

---

## Performance Floor

- No layout-shifting media: every `<img>`/`<video>` has `width`/`height` (or `aspect-ratio`).
- Animate only `transform` and `opacity`; never `top/left/width/height`.
- One stylesheet request for above-the-fold rendering; no `@import` chains.
- Target: Core Web Vitals green (LCP < 2.5s, CLS < 0.1, INP < 200ms) on a mid-range phone, not a dev laptop.
