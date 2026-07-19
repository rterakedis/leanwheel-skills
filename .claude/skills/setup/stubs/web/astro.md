# Astro Patterns

> Updated: 2026-07-19 — Astro 6 (stable 2026-03; requires Node ≥ 22.12, ships Vite 7 + Zod 4)
> Zero-JS discipline, content collections, image pipeline, and routing for Astro static sites.

**v5 → v6 removals to know:** `Astro.glob()` (use content collections or `import.meta.glob`), the old `<ViewTransitions />` component (use `<ClientRouter />`), and Zod 3 schemas (content schemas run on Zod 4). Native CSP support is built in — responsive image styles are hashable, so a strict CSP no longer needs `unsafe-inline` for the image pipeline.

---

## The Zero-JS Default

Astro ships **no JavaScript** unless a component opts in with a `client:*` directive. This is the framework's core value — protect it.

**Rule: every `client:*` directive must be justified in the story file or PR description.** "It was a React component I found" is not a justification. Static markup never needs an island.

```astro
{/* ✅ Static rendering — component runs at build time, ships HTML only */}
<ProductCard product={product} />

{/* ✅ Justified island — interactive search needs client state */}
<SearchBox client:idle />

{/* ❌ Hydrating static content */}
<Footer client:load />
```

Directive choice when an island IS justified:

| Directive | When |
|---|---|
| `client:visible` | Below-the-fold interactivity (default choice) |
| `client:idle` | Above-the-fold, non-critical (search box, theme toggle) |
| `client:load` | Only if the component must be interactive immediately |
| `client:only` | Component cannot render server-side (rare; document why) |

Prefer a plain Astro component + `<script>` tag (vanilla, scoped, no framework runtime) over a framework island for small interactions.

---

## Content Collections

All structured content (posts, docs, projects) lives in content collections with a Zod schema. Markdown files scattered outside collections, or content fetched at runtime, are rejections.

```ts
// ✅ src/content.config.ts
import { defineCollection } from 'astro:content';
import { z } from 'astro/zod';   // v6: z comes from astro/zod (Zod 4), not astro:content
import { glob } from 'astro/loaders';

const blog = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/blog' }),
  schema: ({ image }) => z.object({
    title: z.string().max(70),
    description: z.string().max(160),
    pubDate: z.coerce.date(),
    cover: image().optional(),
    draft: z.boolean().default(false),
  }),
});

export const collections = { blog };
```

- Query with `getCollection('blog', ({ data }) => !data.draft)` — filter drafts at build time.
- Schema validates at build; a missing `description` fails the build instead of shipping a page with no meta description. This is the point — keep schemas strict.

---

## Images

Local images go through `astro:assets` — never a raw `<img>` pointing into `public/`.

```astro
---
// ✅ layout generates srcset/sizes automatically (stable since 5.10)
import { Image } from 'astro:assets';
import hero from '../assets/hero.png';
---
<Image src={hero} alt="Team at the summit" layout="constrained" width={800} height={450} />
```

- Prefer the responsive `layout` prop (`constrained` for most content images, `full-width` for heroes, `fixed` for logos/avatars) over hand-written `widths`/`sizes` — set a site-wide default with `image: { layout: 'constrained' }` in `astro.config.mjs` and override per-image only when needed.

```astro
{/* ❌ Unoptimized, no dimensions, causes layout shift */}
<img src="/images/hero.png" alt="Team at the summit" />
```

- `public/` is only for files that must keep their exact path (favicons, `robots.txt`, OG fallback images).
- Cover images referenced in frontmatter use the `image()` schema helper so they join the pipeline.

---

## Layout, Head, and SEO

- One `BaseLayout.astro` owns `<html>`, `<head>`, and the body scaffold; pages pass `title` and `description` as required props (typed, no defaults that mask missing values).
- A single `<Head>`/`<SEO>` component renders: `<title>`, meta description, canonical URL (from `Astro.site` + `Astro.url.pathname`), Open Graph + Twitter tags, and JSON-LD where DESIGN/EXPERIENCE call for it.
- RSS via `@astrojs/rss` and sitemap via `@astrojs/sitemap` for content sites — both wired in `astro.config.mjs` with `site` set.

---

## Routing & Pagination

- File-based routes in `src/pages/`. Dynamic routes (`[slug].astro`) implement `getStaticPaths()` from the collection — never runtime lookups.
- Pagination uses the built-in `paginate()` helper, not hand-rolled slicing.
- Use `<ClientRouter />` (from `astro:transitions`) only when page-transition polish is a stated design requirement; it adds a script to every page.

---

## Hard Rejections

| Banned | Replacement |
|---|---|
| `client:load` on static content | Remove the directive (or the framework component) |
| `Astro.glob()` (removed in v6) | Content collection + `getCollection`, or `import.meta.glob` for non-content files |
| Framework component for non-interactive markup | Plain `.astro` component |
| `fetch()` of local content at runtime | Content collection + `getCollection` |
| Raw `<img>` for a local asset | `<Image />` / `<Picture />` from `astro:assets` |
| Content `.md` files outside a collection | Move into the collection, extend schema |
| Global CSS dumped in one growing file | Scoped component styles + token layer import |
| `any`-typed or schema-less frontmatter | Zod schema in `src/content.config.ts` |
