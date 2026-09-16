# `/appstore-connect` — App Store Connect authoring lane

> Shipped 2026-08-16 (v1, authoring only). This page is the user documentation; the Decision Log below is the record of why.

---

## Why

App Store Connect wants structured inputs with hard, discover-them-by-failing constraints —
pixel-exact screenshot sizes, character limits on every text field, immutable product IDs,
subscription-group ranking rules. `/appstore-preflight` audits the *code* and hands you a
`[ ]` checklist for everything else. The three parts of that checklist people find hardest
are exactly the three this skill takes over: **assets** (screenshots with device frames and
benefit captions), **metadata** (listing copy, URLs, keywords, release notes), and
**products** (subscription groups, subscriptions, one-time IAPs) — each authored into a
**declarative artifact under `docs/store/`**, enforced by a **zero-token linter** and a
**deterministic Swift compositor**.

## Usage

```
/appstore-connect                                          # status: artifacts per locale, last lint result, PRODUCTS DIFF one-liner
/appstore-connect assets|metadata|products [--locale ll-RR] [--only id] [--regenerate]
```

Default locale is `en-US`. Requires an Apple app project (`.xcodeproj` / `.xcworkspace` /
app-target `Package.swift`); ASSETS additionally requires `scripts/sim.sh` and the app's
`--route`/`--seed` launch-argument contract from `docs/setup/swift/testability.md` — absent →
stop with the one-line fix, never fake a capture.

- **`metadata`** — needs brief/PRD/EXPERIENCE.md/shipped stories; produces lint-clean
  `docs/store/metadata/{locale}/*.txt`.
- **`assets`** — needs the simulator (`sim.sh shots --store`), the app's route/seed
  contract, and **user-supplied bezels** in `docs/store/frames/` (see Prerequisites below);
  produces framed, captioned PNGs at exact store sizes in `docs/store/screenshots/{locale}/`.
  Drafts `docs/store/screenshots.md` first and **stops for human review** — the plan and
  captions are the only judgment call; composition after that is deterministic.
- **`products`** — needs an existing `.storekit`/Swift product-ID literals (brownfield) or a
  short elicitation pass (greenfield); produces `docs/store/products.md` plus a three-way
  diff (spec ↔ `.storekit` ↔ code) with recommendations.

**Frames prerequisite.** Bezels are user-supplied — Apple Design Resources ships only
Sketch/Figma/PSD, nothing fetchable. Export a bezel PNG with a *transparent screen cutout*
from https://developer.apple.com/design/resources/ (Product Bezels), one per required class,
portrait: `docs/store/frames/iphone69.png` and (universal apps) `ipadPro13.png`. Add
`{class}-landscape.png` for landscape plan rows. `compose.swift` auto-detects the cutout by
border flood-fill; if detection fails, add `frames.json` (`{"iphone69": {"screen": [x,y,w,h]}}`).
A missing bezel is a hard stop, not a fallback — a caption-only or bezel-less set is not what
ASSETS produces.

**Manual upload.** v1 is authoring only — nothing talks to App Store Connect. Upload by hand:
App Store Connect ▸ App ▸ Version — paste `metadata/{locale}/*.txt`, upload
`screenshots/{locale}/` per class in `{order}` order, create products from `products.md` and
**attach them to the version** (the #1 IAP rejection is a product created but never attached).
Every op ends with this reminder.

## Artifact contract

`docs/store/` is committed with the project (same standing as `docs/ux/`). Metadata and
screenshots follow the fastlane `deliver` layout; `products.md` is leanwheel-original
(fastlane has no IAP layout). Locale-keyed from day one — a new locale is `--locale es-MX`,
never a redesign.

```
docs/store/
  metadata/
    en-US/   name.txt subtitle.txt description.txt keywords.txt promotional_text.txt
             release_notes.txt privacy_url.txt support_url.txt [marketing_url.txt]
             screenshot-captions.txt        # `id: Caption [| Subtitle]` lines — the per-locale strings
    es-MX/   …                              # second locale (the acceptance test for locale-keying)
    copyright.txt  primary_category.txt  [secondary_category.txt]
    review_information/  first_name.txt last_name.txt email_address.txt phone_number.txt
                         demo_user.txt notes.txt   [demo_password.txt — only on explicit request; it is committed]
  screenshots/{locale}/  {order}_{class}_{id}.png     # 1_iphone69_home.png, 1_ipadPro13_home.png …
  screenshots.md         # the plan (table) — the human review gate for ASSETS
  frames/                # USER-SUPPLIED bezels: iphone69.png, ipadPro13.png [, {class}-landscape.png, frames.json]
  template.json          # OPTIONAL per-project styling; absent = the plain default (see Styling)
  products.md            # subscription groups / subscriptions / one-time IAPs
```

**`screenshots.md` plan shape** (one row per capture):

```markdown
| # | id | route | seed | appearance | orientation | devices |
|---|----|-------|------|------------|-------------|---------|
| 1 | home | home | heavy | light | portrait | iphone69,ipadPro13 |
```

**`screenshot-captions.txt` shape** (per locale, `id: Caption`, ≤ 40 chars, benefit not
feature name, sentence case, no trailing period): `home: See every job at a glance`.
A line may add an optional **subtitle** after the first `|` —
`home: See every job at a glance | Sorted by drive time`. The subtitle renders only where
`template.json` gives it a slot; a **missing subtitle is legal**, a missing caption is not.

**`template.json` (optional styling).** Absent or empty ⇒ the built-in plain style, byte for
byte what compose has always produced — the property every existing project depends on. Present
⇒ merged over those defaults **per key**, so `colors.light.background` can be overridden alone.
It sets `colors.{light,dark}.{background,caption,subtitle,panel,lockup}`, `lockup`
(icon + wordmark), `caption`/`subtitle` (align, maxLines, maxChars, weight), `autoShrink`,
`panel`, `device`, `shadow`, and `geometry.{iphone69,ipadPro13}` — where **every value is a
fraction of canvas W or H**, never a pixel, because the two classes differ too much in aspect
(0.46 vs 0.75) for pixels to carry. Setting `deviceTop`+`deviceWidth` pins the device (it may
bleed off the bottom and clip) instead of fitting it below the caption; setting
`textBlockTop`+`textBlockBottom` gives caption and subtitle fixed slots so the device sits at
the same height across the set. A malformed template — unknown key included — is a **named
error that writes nothing**, never a silent fall back to plain. See DD-68.

**`products.md` shape** (markdown tables — human-editable, greppable):

```markdown
# Products
<!-- source-of-truth: {path/to/App.storekit} (imported {date}) → spec thereafter -->

## Subscription Group: {group ref name}
| product id | ref name | duration | level | family sharing | intro offer | promo offers |
|---|---|---|---|---|---|---|
| com.x.pro.monthly | Pro Monthly | P1M | 1 | no | 7-day free trial | — |
### Localizations
| locale | product id | display name | description | group display name |
|---|---|---|---|---|

## One-time IAPs
| product id | ref name | type | family sharing |
|---|---|---|---|
### Localizations
| locale | product id | display name | description |

## Review
| product id | review screenshot | review notes |
```

Duration is ISO-8601 (`P1W`/`P1M`/`P1Y`); level = subscription-group ranking (1 = highest
tier); type ∈ consumable / non-consumable / non-renewing.

## Decision tree

| State | Op / sub-op that runs |
|---|---|
| no `docs/store/`, artifact requested | draft it from the relevant inputs (see Usage) |
| ASSETS, no plan yet | draft `screenshots.md` + captions, **stop for review** |
| ASSETS, plan exists, `--regenerate` not passed | capture missing rows → compose → lint |
| ASSETS, `--only id` | capture/compose just that row |
| METADATA, locale dir absent | draft all files for that locale |
| METADATA, `--locale` is a second locale | copy `en-US` structure, translate, flag `[TRANSLATE]` on low confidence |
| PRODUCTS, no `products.md`, `.storekit`/ID literals exist | **IMPORT** → then DIFF |
| PRODUCTS, no `products.md`, nothing in the project (greenfield) | short `elicit` pass → write spec → **GENERATE** |
| PRODUCTS, `products.md` exists, no `--regenerate` | **DIFF** (default) |
| PRODUCTS, `products.md` exists, `--regenerate` passed | **GENERATE** (overwrites `.storekit`) |

## Scripts

Beside `SKILL.md` at `{skills_path}/.claude/skills/appstore-connect/` (`{skills_path}` from
`.leanwheel/manifest.json`, or the directory containing SKILL.md):

- **`compose.swift`** — `swift compose.swift --locale en-US [--store-dir docs/store] [--captures .leanwheel/sim/store] [--only id,id] [--dry-run]`. Plan × devices → framed, captioned PNGs at exact store size. Validates everything first and writes nothing on any error (all-or-nothing).
- **`asc-lint.sh`** — `bash asc-lint.sh [docs/store] [--locale ll-RR] [--no-network] [--quiet]`; exit 1 on ERROR. Also scaffolded into projects as `.claude/hooks/asc-lint.sh` (advisory PostToolUse on any `docs/store/` write; `/setup` Step 3e / `/upgrade-project`) — the project hook copy is preferred when present.
- **`scripts/sim.sh shots --store`** — one call per plan row: `scripts/sim.sh shots {id} --store --route {route} --seed {seed} --locale {locale} --devices {devices} --appearances {appearance} [--orientation landscape]`. Forces native pixels, `large` text size, and **dies** if a capture's pixel size isn't an accepted store size.

**Store device/size table** (the only two classes App Store Connect requires today — it
scales these down to every smaller class):

| Class | Device | Accepted size (portrait) |
|---|---|---|
| `iphone69` | iPhone 17 Pro Max | 1320×2868 (also 1290×2796) |
| `ipadPro13` | iPad Pro 13-inch (M5) | 2064×2752 (also 2048×2732) |

Recorded as `store_devices` in `.leanwheel/sim.json` (the everyday `devices` pair — iPhone 17
/ iPad Pro 11" — captures at non-accepted sizes).

## Wiring

- **From `/appstore-preflight`:** its checklist's Media / App Record / IAP `[ ]` lines point
  here; on re-run preflight calls PRODUCTS DIFF as its IAP step and stamps
  `[x] verified — asc-lint passed ({date})` on the metadata/screenshot lines once
  `docs/store/` exists and the lint is clean.
- **`refresh-swift` Step 4** refreshes the store facts (screenshot classes/sizes in
  `op-assets.md`, char limits in `op-metadata.md`) alongside `appstore-preflight`'s facts,
  and bumps the SKILL.md Currency note date.
- **Layout:** SKILL.md holds only what every op shares (inventory, the `docs/store/` tree,
  hand-offs); each op is a sibling `op-{assets,metadata,products}.md` read only by that op.
  Preflight's IAP step reads `op-products.md` alone (DD-74).
- **Hooks:** `asc-lint.sh` is scaffolded to `.claude/hooks/asc-lint.sh` (`/setup` Step 3e /
  `/upgrade-project`) as an advisory PostToolUse hook on any `docs/store/` write.
- **Never:** invent UI, embellish captures with generated imagery, write anything into ASC,
  run inside a flywheel, or install a package-manager dependency.

## Planned improvements

- **v2 `asc` client** (Swift script, CryptoKit ES256 JWT + URLSession) — sequencing parked:
  read/diff first (apps, versions, localizations, screenshot sets, subscription
  groups/products against `docs/store/`), then metadata + screenshot writes (reversible:
  localizations PATCH, screenshot reserve → upload → commit), then products writes (sticky —
  product IDs immutable, live groups hard to remove — so last).
- App previews as a first-class op (currently a manual `simctl io recordVideo` note in
  SKILL.md, not automated).
- Locales beyond the `en-US`/`es-MX` pair.
- Metadata drift check against live ASC once the read side exists.
- `/next` routing to `/appstore-connect` once a version is being cut.

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
- 2026-08-16 — Build-time implementation choices (grilled, settled): products.md = markdown tables; plan = one markdown table `# | id | route | seed | appearance | orientation | devices` + `id: caption` lines per locale; bezels user-supplied (ADR ships no fetchable PNGs) with alpha auto-detect + frames.json override, missing bezel = hard stop; linter = bash asc-lint.sh (hook-fast), one file in two places (skill + hooks stub); store classes iphone69 = iPhone 17 Pro Max 1320×2868, ipadPro13 = iPad Pro 13-inch (M5) 2064×2752 via sim.json store_devices; one `shots --store` call per plan row — source: build session

- 2026-08-29 — Per-project screenshot **styling** is an optional `docs/store/template.json`, merged over the built-in plain style **per key** (colours, lockup, panel, shadow, per-class geometry as canvas fractions; captions gain an optional `| Subtitle`). Absent, empty, or malformed-and-rejected ⇒ the plain default renders byte-identically; a malformed template is a named error that writes nothing, unknown keys included, so a typo cannot silently downgrade a branded set to plain. Defaults are the *original expressions* rather than equivalents (`0.94`, not `1 - 0.06`), and keys whose absence selects an unexpressible old behaviour default to nil (`captionLeading`, `deviceTop`+`deviceWidth`, `textBlockTop`+`textBlockBottom`) — why: `compose.swift` is symlink-shared by every project, so one project's brand must be impossible to leak into another's renders, and the no-template path is the one every existing project already depends on. See DD-68 — source: build session
- 2026-08-29 — No rendering behaviour may be gated on "a template exists". The bezel-silhouette capture clip (which stops the capture spilling into the corner slivers the bezel does not cover — invisible against the plain near-white background, glaring behind a coloured panel) is the explicit key `device.clipCaptureToBezel`, defaulting to whether a panel is drawn — why: gating it on template *presence* made a colours-only template silently change unrelated pixels in the other appearance, breaking the per-key override guarantee — source: build session
- 2026-09-16 — Ops split into `op-assets.md` / `op-metadata.md` / `op-products.md`, each read only by its own op; SKILL.md keeps the shared inventory, tree, and hand-offs — why: the ops never run together, so every run paid for all three (22.7 KB); now 8–17 KB depending on op. `op-` prefix because `products.md` would collide with the `docs/store/products.md` artifact it writes (DD-74).

## Rejected
- 2026-08-29 — Re-implementing the full `template.json` schema in `asc-lint.sh` — why: bash 3.2 with no jq/python would need a lot of fragile pseudo-parsing for no safety gain, since `compose.swift --dry-run` already validates completely and for free. The linter keeps only the cheap checks worth catching as you type: object shape, balanced braces, opaque 6-digit hex, canvas fractions in 0…1, icon paths resolve — source: build session
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
