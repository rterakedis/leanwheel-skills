# Hugo Patterns

> Updated: 2026-06-12 — Hugo 0.146+ (new template system)
> Page bundles, template structure, asset pipeline, and image processing for Hugo sites.

---

## Content Organization: Page Bundles

Content and its resources travel together. A post with images is a **leaf bundle**; a section landing page is a **branch bundle**.

```
content/
  blog/
    _index.md              ← branch bundle: the /blog/ listing page
    my-first-post/
      index.md             ← leaf bundle: the post
      cover.jpg            ← page resource, processed via .Resources
  about.md                 ← standalone page (no resources) is fine
```

```markdown
❌ content/blog/my-first-post.md + static/images/my-first-post-cover.jpg
   (image divorced from content, bypasses image processing)
```

Access bundle images with `.Resources.Get "cover.jpg"` — never hardcode `/images/...` paths to `static/`.

---

## Template Structure

Hugo 0.146 reworked template lookup: templates live directly under `layouts/` (the `_default/` directory is legacy), and markdown render hooks live in `layouts/_markup/`. Older themes still use `_default/` — both resolve, but new code follows the new layout.

```
layouts/
  baseof.html              ← skeleton: <html>, <head>, {{ block "main" . }}
  home.html                ← homepage
  page.html                ← single pages
  section.html             ← list pages (blog index)
  taxonomy.html / term.html
  _partials/
    head.html              ← meta, SEO, CSS pipeline
    nav.html
  _markup/
    render-image.html      ← processes ALL markdown images
    render-link.html
```

Rules:
- All shared markup is a partial. Pass explicit context: `{{ partial "nav.html" . }}` or a dict — never rely on globals.
- Expensive partials that don't vary per-page use `partialCached` (with variant keys when they vary by section).
- `baseof.html` + `block` is the only inheritance mechanism — no copy-pasted `<head>` across templates.

---

## URLs and Links

| Need | Use |
|---|---|
| Link to another content page | `{{ with .GetPage "/blog/my-post" }}{{ .RelPermalink }}{{ end }}` or `relref` shortcode in markdown |
| Link to a static/asset path | `relURL` / `absURL` |
| Site base URL | `.Site.BaseURL` via the functions above — never hardcoded |

Hardcoded absolute URLs (`https://mysite.com/...`) or root-relative paths that bypass `relURL` break on subpath deploys and staging — rejection in review.

---

## Asset Pipeline (Hugo Pipes)

CSS and JS go through `assets/` and Hugo Pipes — never raw files in `static/` that skip fingerprinting.

```go-html-template
{{/* ✅ in _partials/head.html */}}
{{ with resources.Get "css/main.css" | css.Sass | minify | fingerprint }}
  <link rel="stylesheet" href="{{ .RelPermalink }}" integrity="{{ .Data.Integrity }}">
{{ end }}
```

- `css.Sass` for Sass (the old `toCSS` name is deprecated); `js.Build` (esbuild) for any JS.
- `fingerprint` on everything cacheable.

---

## Image Processing

Every content image is processed — resized, converted to WebP, with explicit dimensions. The render hook makes this automatic for markdown images:

```go-html-template
{{/* ✅ layouts/_markup/render-image.html */}}
{{ with .PageInner.Resources.Get .Destination }}
  {{ $img := .Resize "800x webp q85" }}
  <img src="{{ $img.RelPermalink }}" width="{{ $img.Width }}" height="{{ $img.Height }}"
       alt="{{ $.Text }}" loading="lazy">
{{ end }}
```

`❌` Raw `![](cover.jpg)` rendering to an unprocessed, dimension-less `<img>` — install the render hook first, then markdown stays clean.

---

## Shortcodes vs Partials

| Use | For |
|---|---|
| Shortcode (`layouts/_shortcodes/`) | Authors embedding rich elements in markdown (`{{</* video id="..." */>}}`) |
| Partial | Template-level reuse (nav, cards, head) |
| Neither — raw HTML in markdown | ❌ Never; if markdown needs markup, write a shortcode |

---

## Configuration & Taxonomies

- `hugo.toml` (not legacy `config.toml`); split into `config/_default/` directory only when environments genuinely diverge.
- Declare taxonomies explicitly; remove the defaults you don't use (`disableKinds` for unused page kinds — stops Hugo generating empty taxonomy pages).
- `enableGitInfo = true` for accurate `Lastmod` dates on content sites.

---

## Hard Rejections

| Banned | Replacement |
|---|---|
| Hardcoded URLs / paths | `relref`, `relURL`, `.RelPermalink` |
| Images in `static/` referenced by path | Page bundle resources + render hook processing |
| CSS/JS in `static/` | `assets/` + Hugo Pipes + `fingerprint` |
| Raw HTML blocks in markdown | Shortcode |
| Copy-pasted `<head>`/nav across templates | `baseof.html` blocks + partials |
| Logic-heavy templates querying `.Site.Pages` repeatedly | Compute once, `partialCached`, or restructure content |
