# Web / SSG projects — read only when `docs/setup/web/` exists, or `package.json` is present

Applied from Activation step 4b and Build & Test Gate step 1.

## Guidance routing (Activation step 4b)

When `docs/setup/web/` exists, read the files relevant to this story's tasks before implementing:

- Stylesheets, tokens, or layout → `docs/setup/web/css-design-system.md`
- Pages, forms, or content templates → `docs/setup/web/accessibility-seo.md`
- `docs/setup/web/astro.md` if it exists and the story touches `.astro` files, collections, or images
- `docs/setup/web/hugo.md` if it exists and the story touches `layouts/`, `content/`, or `assets/`
- `docs/setup/web/anti-patterns.md` if present

## Build + test command (Build & Test Gate step 1)

When `package.json` is present: run the project's build + test scripts with their quiet reporter (e.g. `npm run build --silent && npx vitest run --reporter=dot`, or the lint/typecheck script if no tests), same `tee .leanwheel/logs/build-test.log | tail -n 40` pattern.
