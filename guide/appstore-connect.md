# `/appstore-connect` — App Store Connect authoring lane

> **Status: living design doc.** This file is the brief for a skill that does not exist yet.
> It carries the intent, the intended shape, and the decision log from the ideation session
> that produced it. Once the skill ships, rewrite this as user documentation: usage, the
> artifact contract, the decision tree, and planned improvements. Until then, a build session
> (`/dev-single-goal` or a direct authoring pass) should treat the **Decision Log** below as
> settled and grill only what it leaves open.

---

## Why

App Store Connect wants structured inputs with hard, discover-them-by-failing constraints —
pixel-exact screenshot sizes, character limits on every text field, immutable product IDs,
subscription-group ranking rules. Today leanwheel's `appstore-preflight` audits the *code*
and hands you a `[ ]` checklist for everything else. The three parts of that checklist people
find hardest are exactly the three this skill takes over:

1. **Assets** — screenshots (and previews) with device frames and benefit captions
2. **Metadata** — the listing copy, URLs, keywords, release notes
3. **Products** — subscription groups, subscriptions, one-time IAPs

The pattern is the same for all three, and it is the pattern leanwheel already uses
elsewhere (see the memory note *verifiable artifacts over guardrails*): a **declarative
artifact under `docs/store/`** the model authors from docs it already has (brief, PRD,
EXPERIENCE.md, the codebase), a **zero-token linter** that enforces Apple's constraints, and —
later — a **thin push step** that is executed, never reasoned about.

## What we intend to build

### One skill, three composable ops

`/appstore-connect` — same composable-op shape as `docs-sync`. `appstore-preflight` stays the
audit; it hands off to this skill for authoring and calls its PRODUCTS `DIFF` as its IAP step.

| Op | Input | Output |
|---|---|---|
| **ASSETS** | `docs/store/screenshots.md` plan; simulator via `sim.sh shots` | Framed, captioned PNGs at exact App Store sizes in `docs/store/screenshots/{locale}/` (+ optional previews via `simctl io recordVideo` along a `flow`) |
| **METADATA** | brief / PRD / EXPERIENCE.md / shipped stories | `docs/store/metadata/{locale}/*.txt` — lint-clean listing copy |
| **PRODUCTS** | existing `.storekit` config + StoreKit product-ID literals in Swift (brownfield) or an `elicit` pass (greenfield) | `docs/store/products.md` spec, a three-way **diff** (spec ↔ `.storekit` ↔ code) with **recommendations**; `.storekit` generated only on greenfield / `--regenerate` |

### The artifact tree — `docs/store/`

Committed with the project (same standing as `docs/ux/`). The metadata/screenshot halves
follow the **fastlane `deliver` layout** so any downstream tooling — a future leanwheel push
layer, or someone else's — consumes it unchanged. The products half is leanwheel-original
(fastlane has no IAP layout).

```
docs/store/
  metadata/
    en-US/   name.txt  subtitle.txt  description.txt  keywords.txt
             promotional_text.txt  release_notes.txt  privacy_url.txt  support_url.txt
             screenshot-captions.txt          # per-locale caption strings for the plan
    es-MX/   …                                 # second locale — the acceptance test
    copyright.txt  primary_category.txt  review_information/…
  screenshots/
    en-US/   1_iphone69_home.png  2_iphone69_paywall.png  1_ipadPro13_home.png …
    es-MX/   …
  screenshots.md                               # the plan: ordered {headline, route, seed, appearance}
  frames/                                      # Apple Design Resources bezels (fetched once)
  products.md                                  # subscription groups / subscriptions / IAPs
```

Every artifact is locale-keyed from day one; adding a locale is a re-run (`--locale es-MX`),
never a redesign. Caption *strings* live in the locale folder, not in the plan file.

### The ASSETS pipeline

`sim.sh shots --store` (new preset: required device classes only, exact App Store pixel
sizes, light + dark, each shot landing on a named `--route` with `--seed heavy` so the data
looks real, `-AppleLanguages` per locale) → **`compose.swift`** (single-file Swift script,
CoreGraphics/CoreText: capture → bezel from `docs/store/frames/` → benefit caption in SF →
exact output size) → `docs/store/screenshots/{locale}/`. The plan file
`docs/store/screenshots.md` is the human review gate: the model drafts it from PRD/UX, you
edit the words, and composition is deterministic after that.

### The METADATA lint

A zero-token script (`asc-lint.sh` or Swift): name ≤ 30, subtitle ≤ 30, keywords ≤ 100 with
comma rules and no app-name repetition, promotional text ≤ 170, description / release notes
≤ 4000, URLs resolve, every locale carries every required file. Runnable standalone and as
an advisory PostToolUse hook like `guard-design-tokens.sh`. `appstore-preflight`'s checklist
turns these `[ ]` lines into `[x] verified — lint passed`.

### PRODUCTS is reconcile-first

Brownfield projects already carry a `.storekit` from earlier stories, so the op never asks
you to re-describe what the code declares:

- **IMPORT** — seed `products.md` from the existing `.storekit` and the product-ID literals in
  Swift.
- **DIFF** — spec ↔ `.storekit` ↔ code, three ways, plus a **recommendations** section
  grounded in Apple's invariants and IAP-rejection footguns: group structure and levels for
  mutually-exclusive tiers, missing localizations, missing review screenshots, immutable-ID
  renames, family-sharing / intro-offer gaps, "products created but never attached to the
  version".
- **GENERATE** — write `.storekit` from the spec on greenfield or explicit `--regenerate`. On
  first run the existing file is authoritative; the spec is the source of truth thereafter.
- The ↔ *live ASC* leg of the diff arrives in v2 with the client (below).

### Tooling constraint

**No new package-manager installs.** bash, stdlib-only Python 3, Go, or a Swift script are
all acceptable; nothing via gem / pip / npm. The lean default is single-file Swift: the only
environment that ever needs any of this already has Xcode, so Swift is guaranteed-present —
CryptoKit signs the ES256 JWT natively and URLSession does the HTTP for the v2 client, and
CoreGraphics does the composition now.

### Cross-cutting wiring (planned)

- `/next` routes to `/appstore-connect` once the readiness stamp exists and a version is
  being cut.
- `refresh-swift` Step 4 extends its volatile-facts refresh to screenshot dimensions, char
  limits, and (v2) API endpoint changes.
- ASC API auth setup (`.p8`, key ID, issuer ID → env / keychain; `guard-secrets.sh` already
  blocks committing the key) documented via `docs-sync OPERATIONAL` when the client lands.
- Any push is explicit-permission territory: dry-run diff by default, `--apply` to write,
  never inside a flywheel.

## v2 and beyond (not committed)

- **`asc` client** (Swift script) — sequencing parked: read/diff first (apps, versions,
  localizations, screenshot sets, subscription groups/products against `docs/store/`), then
  metadata + screenshot writes (reversible: localizations PATCH, screenshot
  reserve → upload → commit), then products writes (sticky — product IDs immutable, live
  groups hard to remove — so last).
- Multi-locale ASSETS beyond es-MX; app previews as a first-class op.
- Metadata drift check against live ASC once the read side exists.

---

# Decision Log

## Destination
A spec for an App Store Connect authoring lane in leanwheel-skills — the artifacts + gates that make assets (screenshots/previews), metadata, and subscription groups/products easy to configure and hard to get wrong. Stakes: maintainer's own app is at submission now (real deadline); the skills also ship to plugin testers, so the shape must generalize.

## Decisions
- 2026-08-15 — ASC client tooling must need **no new package-manager installs**: bash, stdlib-only Python 3, Go, or a Swift script are all acceptable; nothing via gem/pip/npm — why: maintainer already has Python + Go (Hugo) and Xcode/Swift; won't add framework sprawl. Lean default: a single-file **Swift script** (`swift asc.swift` — CryptoKit does ES256 JWT natively, URLSession does the HTTP; every machine that can submit to the App Store already has Xcode, so it's guaranteed-present with zero deps), with Python/Go as fallbacks if Swift-script ergonomics disappoint — source: /ideate
- 2026-08-15 — One skill, `/appstore-connect`, covering all three surfaces as composable ops: ASSETS (screenshots/previews with device frames + benefit captions), METADATA (listing copy), PRODUCTS (subscription groups / subscriptions / IAP) — why: one authoring lane, one artifact tree, one mental model; `appstore-preflight` stays the audit and hands off to it — source: /ideate
- 2026-08-15 — v1 is **authoring only**: generate copy/data/screenshots into `docs/store/` using a fastlane-`deliver`-compatible layout (`metadata/{locale}/*.txt`, `screenshots/{locale}/`) extended with a `products` spec (fastlane has no IAP layout — this part is leanwheel-original); upload is manual via the ASC web UI — why: fastest to the maintainer's deadline; the deliver contract is the ecosystem convention, so a future push layer (or anyone else's tooling) consumes it unchanged — source: /ideate
- 2026-08-15 — `docs/store/` is committed with the project (same standing as `docs/ux/`) — why: it is planning/product content, not build output; version history of copy and screenshot plans is wanted — source: /ideate
- 2026-08-15 — Screenshot composition = a single-file **Swift script** (`compose.swift`, CoreGraphics/CoreText): capture from `sim.sh shots` → device bezel from `docs/store/frames/` (Apple Design Resources bezels, fetched once / small set shipped with the skill) → benefit caption in SF → exact App Store pixel sizes; driven by a reviewable plan file `docs/store/screenshots.md` (ordered {headline, route, seed, appearance}) that the model drafts from PRD/UX and the user edits — why: zero deps on any Xcode machine, pixel-deterministic, same toolchain as the future `asc` script; the plan file is the human review gate so composition never needs judgment — source: /ideate
- 2026-08-15 — Locales: v1 ships **en-US only**, but every artifact is locale-keyed from day one and adding a locale is a re-run, not a redesign — `metadata/{locale}/`, `screenshots/{locale}/`, caption strings live in the locale's metadata dir (not in the plan file), products spec carries per-locale display name/description, and ASSETS captures with `-AppleLanguages <locale>` via a `--locale` flag; **es-MX is the named second locale** and is the acceptance test for this property (a dry run of `--locale es-MX` should fail only on missing translations, never on structure) — why: es-MX lands shortly after launch; translated *copy* is a human/model task per locale, the pipeline must not be — source: /ideate
- 2026-08-15 — PRODUCTS is **reconcile-first, brownfield-aware**: (a) IMPORT — if a `.storekit` config and/or StoreKit product-ID literals exist in the project, seed `docs/store/products.md` from them (never ask the user to re-describe what the code already declares); (b) DIFF — report spec ↔ `.storekit` ↔ Swift product-ID literals three ways, plus a **recommendations** section grounded in Apple's invariants and IAP-rejection footguns (group structure/levels for mutually-exclusive tiers, missing localizations, missing review screenshots, immutable-ID renames, family-sharing/offer gaps, "products created but not attached to the version"); (c) GENERATE `.storekit` only on greenfield or explicit `--regenerate` (existing file is authoritative on first run; the spec becomes the source of truth thereafter). `appstore-preflight` calls DIFF as its IAP step. The ↔ live-ASC leg joins in v2 with the `asc` client — why: the maintainer's app already carries a `.storekit` from earlier epics; the skill's value is telling you what's wrong/missing versus what ASC will demand, not making you type it twice — source: /ideate
- 2026-08-16 — This file (`guide/appstore-connect.md`) is the decision log's home and the build brief; it will be rewritten as user documentation once the skill ships — why: this repo ships skills, not `docs/` planning docs, so `/spec` has no render target; one committed living doc serves both roles — source: /ideate

## Rejected
- 2026-08-15 — fastlane (deliver/snapshot/frameit/precheck) as the upload/capture layer — why: Ruby gem toolchain on the maintainer's Mac is unwanted; leanwheel tooling must stay zero-dependency (bash/curl/openssl/xcrun/sips only, the `sim.sh` posture) — source: /ideate
- 2026-08-15 — AI image-enhancement stage for screenshots (Gemini/Nano-Banana-style, as in adamlyttle's skill) — why: nondeterministic, external MCP dependency, and Guideline 2.3.3 (screenshots must show the real UI) makes embellishment a rejection risk — source: /ideate
- 2026-08-15 — HTML/CSS + headless-browser composition and Python/Pillow composition — why: renderer (Chrome) / library (Pillow) aren't guaranteed-present; Swift is on every submitting machine — source: /ideate

## Not yet specified
- v2: ASC client (`asc` Swift script) — read/diff first, then metadata+screenshot writes, then products writes? (parked; not v1)

## Out of scope

---

## References

- Apple asset best practices — https://developer.apple.com/app-store/asset-best-practices/
- App Store Connect API — https://developer.apple.com/documentation/appstoreconnectapi
- adamlyttle's ASO screenshot skill (idea source for benefit-first composition; its Pillow +
  Gemini pipeline is deliberately not ported) —
  https://github.com/adamlyttleapps/claude-skill-aso-appstore-screenshots
- fastlane `deliver` (layout contract only; the tool itself is rejected) —
  https://docs.fastlane.tools/actions/deliver/
