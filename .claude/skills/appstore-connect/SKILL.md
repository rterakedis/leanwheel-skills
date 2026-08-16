---
name: appstore-connect
description: Author the App Store Connect inputs for an Apple app as lint-clean, committed artifacts under docs/store/ — framed screenshots at exact store sizes (ASSETS), listing copy per locale (METADATA), and a subscription-group / IAP spec reconciled against the project's .storekit and code (PRODUCTS). Use when the user says "app store connect", "appstore connect", "store listing", "app store screenshots", "store metadata", "release notes", "subscription products", "IAP spec", or after /appstore-preflight hands off. Called by /appstore-preflight for its IAP step (PRODUCTS DIFF).
---

# App Store Connect Skill

**Goal:** Turn the three hardest parts of the submission checklist — screenshots, listing copy, and products — into **declarative artifacts under `docs/store/`** the model drafts from docs it already has (brief, PRD, `docs/ux/EXPERIENCE.md`, shipped stories, the codebase), enforced by a **zero-token linter** and a **deterministic compositor**. Everything is authored *into the repo*; upload is by hand in the App Store Connect web UI (a push client is a v2 item, never inside a flywheel). Same composable-op shape as `docs-sync`: three ops, each gated and idempotent.

**Requires:** an Apple app project (`.xcodeproj` / `.xcworkspace` / app-target `Package.swift`). ASSETS additionally requires `scripts/sim.sh` (Apple projects scaffolded by `/setup`; `/upgrade-project` adds it) and the app's `--route` / `--seed` launch-argument contract from `docs/setup/swift/testability.md`. Absent → stop with the one-line fix; never fake a capture.

**Currency note:** Store facts embedded here (screenshot classes/sizes, character limits) are current as of **August 2026** and are refreshed by `/refresh-swift` Step 4 alongside `appstore-preflight`'s. Screenshot classes: only **6.9" iPhone** and **13" iPad** are required; App Store Connect scales those down to every smaller class. Accepted sizes: iPhone 6.9" `1320×2868` / `1290×2796`; iPad 13" `2064×2752` / `2048×2732` (landscape = swapped).

**Division of labour:** `/appstore-preflight` audits the *code* and writes the checklist; this skill authors what the checklist asks for and hands verified facts back (`asc-lint` result, PRODUCTS DIFF).

**Token posture:** every op starts from a zero-token inventory; the model writes small text files and reads only the planning docs it needs; capture, composition, and lint are scripts (`sim.sh`, `compose.swift`, `asc-lint.sh`) that are *executed, never read into context*.

---

## The artifact tree — `docs/store/` (committed, same standing as `docs/ux/`)

Metadata and screenshots follow the **fastlane `deliver` layout** so any downstream tooling consumes them unchanged; `products.md` is leanwheel-original (fastlane has no IAP layout). Locale-keyed from day one — adding a locale is `--locale es-MX`, never a redesign.

```
docs/store/
  metadata/
    en-US/   name.txt subtitle.txt description.txt keywords.txt promotional_text.txt
             release_notes.txt privacy_url.txt support_url.txt [marketing_url.txt]
             screenshot-captions.txt        # `id: Caption` lines — the per-locale caption strings
    es-MX/   …                              # second locale (the acceptance test for locale-keying)
    copyright.txt  primary_category.txt  [secondary_category.txt]
    review_information/  first_name.txt last_name.txt email_address.txt phone_number.txt
                         demo_user.txt notes.txt   [demo_password.txt — only on explicit request; it is committed]
  screenshots/{locale}/  {order}_{class}_{id}.png     # 1_iphone69_home.png, 1_ipadPro13_home.png …
  screenshots.md         # the plan (table) — the human review gate for ASSETS
  frames/                # USER-SUPPLIED bezels: iphone69.png, ipadPro13.png [, {class}-landscape.png, frames.json]
  products.md            # subscription groups / subscriptions / one-time IAPs
```

Scripts beside this file (`{skills_path}/.claude/skills/appstore-connect/`, where `{skills_path}` is `.leanwheel/manifest.json` → `skills_path`, or the directory containing this SKILL.md):
- **`compose.swift`** — `swift compose.swift --locale en-US [--store-dir docs/store] [--captures .leanwheel/sim/store] [--only id,id] [--dry-run]`. Plan × devices → framed, captioned PNGs at exact store size. Validates *everything* first and writes nothing on any error.
- **`asc-lint.sh`** — `bash asc-lint.sh [docs/store] [--locale ll-RR] [--no-network] [--quiet]`; exit 1 on ERROR. Also scaffolded into projects as `.claude/hooks/asc-lint.sh` (advisory PostToolUse on any `docs/store/` write; `/setup` Step 3e / `/upgrade-project`). Prefer the project hook copy when present.

---

## Step 0 — Inventory (zero-token, every op)

```bash
ls -R docs/store 2>/dev/null | head -80
ls docs/store/metadata 2>/dev/null                                    # locales present
ls docs/store/frames 2>/dev/null                                      # bezels present?
find . -name "*.storekit" ! -path "*/DerivedData/*" ! -path "*/.build/*"
grep -rnoE '"[a-z0-9_.]+\.(monthly|yearly|annual|weekly|lifetime|pro|premium|plus)[a-z0-9_.]*"|Product\.products\(for:|productIDs?|ProductID' --include=*.swift . | head -40
ls docs/project/brief.md docs/prd.md docs/ux/EXPERIENCE.md docs/epics.md docs/maintainer/appstore-submission-checklist.md 2>/dev/null
[ -x scripts/sim.sh ] && plutil -extract store_devices json -o - .leanwheel/sim.json 2>/dev/null
[ -x .claude/hooks/asc-lint.sh ] && echo "lint: project hook" || echo "lint: skill copy"
```

Record: locales, which artifacts exist, `.storekit` path(s), product-ID literals, whether `sim.sh`/`store_devices`/frames are ready. Read `docs/project/brief.md`, `docs/prd.md`, and `docs/ux/EXPERIENCE.md` **only for the op that needs them** (METADATA and the ASSETS plan draft); never the whole codebase.

**Op selection:** `/appstore-connect` with no argument prints a one-screen status (artifacts present per locale · last `asc-lint` result · PRODUCTS DIFF one-liner) and recommends the next op. Explicit: `/appstore-connect assets|metadata|products [--locale ll-RR] [--only id] [--regenerate]`. Default locale `en-US`.

---

## METADATA — listing copy per locale

**Input:** brief / PRD / EXPERIENCE.md / shipped stories (`docs/epics.md` `status: done` rows since the last release, or `git log` since the last tag) / the preflight checklist (URLs, category, detected facts).

1. **Draft** every file for `metadata/{locale}/` (+ root files on first run). Rules that keep review honest and the lint green:
   - **Real features only** — nothing the shipped build doesn't do (Guideline 2.3). Description leads with the outcome, then 3–5 concrete capabilities, then who it's for; no competitor names, no "best"/"#1", no price claims that can go stale.
   - `name` ≤ 30 · `subtitle` ≤ 30 (a benefit, not a tagline) · `keywords` ≤ 100 chars, comma-separated **without spaces**, never repeating a word from the name (Apple already indexes it), no plurals of the same word, no category names · `promotional_text` ≤ 170 (updatable without a build — use it for what's *new*) · `description`/`release_notes` ≤ 4000.
   - `release_notes` = user-facing changes from the shipped stories, plain language, no story IDs.
   - URLs come from the preflight checklist or the user; write only `https://`. `review_information/` is written from the user's answers; `demo_password.txt` only when explicitly asked (say once that it will be committed — the checklist already tells them the demo account must be real and 2FA-free).
2. **Second locale** (`--locale es-MX`): copy the *structure* from `en-US`, translate every file (natural, not literal; keywords re-researched for the locale, not translated word-for-word), and mark anything you couldn't translate confidently with `[TRANSLATE]` so the human sees it. Structure must never be the thing that fails.
3. **Lint** — run `asc-lint.sh` for the locale (network on). Fix ERRORs and re-run until clean; report WARNs.
4. **Return:** `METADATA: {locale} — {N} files written, lint {clean | E errors / W warnings}`.

---

## ASSETS — framed screenshots at exact store sizes

Pipeline: `sim.sh shots --store` (one call per plan row → native captures, light+dark, `--seed heavy`, `-AppleLanguages` per locale) → `compose.swift` (bezel from `docs/store/frames/` + caption from the locale's `screenshot-captions.txt` → exact size) → `docs/store/screenshots/{locale}/`. Composition needs no judgment; the **plan file is the human review gate**.

1. **Preconditions (hard stops, one report):** `scripts/sim.sh doctor` passes; `.leanwheel/sim.json` has `store_devices` (missing → `rm .leanwheel/sim.json && scripts/sim.sh doctor` to re-derive; the defaults are iPhone 17 Pro Max / iPad Pro 13-inch (M5) — both must exist in Simulator; edit if not); `docs/store/frames/iphone69.png` and (universal apps) `ipadPro13.png` exist. **Frames are user-supplied:** export a bezel PNG with a *transparent screen cutout* from Apple Design Resources (https://developer.apple.com/design/resources/ — Product Bezels), one per class, portrait; add `{class}-landscape.png` for landscape rows; `frames.json` (`{"iphone69": {"screen": [x,y,w,h]}}`) only if auto-detection of the cutout fails. Do not proceed to capture without them — a caption-only or bezel-less set is not what this op produces.
2. **Draft the plan** — `docs/store/screenshots.md`, 5–8 rows, from EXPERIENCE.md's primary flows + PRD value props. Benefit-first: the first three shots carry the pitch (outcome, core action, proof), later shots cover breadth; paywall last unless the product *is* the subscription; one dark-appearance row is enough. Each row names the **route** and **seed** the app already supports (`testability.md`'s route table / `SeedScenario`s — never invent one; a route the app lacks becomes a one-line "add route X" note, not a fake row).

   ```markdown
   | # | id | route | seed | appearance | orientation | devices |
   |---|----|-------|------|------------|-------------|---------|
   | 1 | home | home | heavy | light | portrait | iphone69,ipadPro13 |
   ```
   Write the caption strings to `metadata/{locale}/screenshot-captions.txt` (`home: See every job at a glance`) — ≤ 40 chars, a benefit not a feature name, sentence case, no trailing period. **Stop here for review**: "Edit the plan/captions if you want, then say continue." Composition is deterministic after this; the words are the only judgment.
3. **Capture** — one `shots --store` call per row, per locale:
   ```bash
   scripts/sim.sh shots {id} --store --route {route} --seed {seed} --locale {locale} \
     --devices {devices} --appearances {appearance} [--orientation landscape]
   ```
   `--store` forces native pixels, `large` text size only, verifies each capture's pixel size against the accepted table and **dies** on a non-6.9"/13" device. A capture that looks like the launch screen is a dropped route until proven otherwise (`docs/setup/swift/simulator.md` ▸ When it goes wrong).
4. **Compose** — `swift {skills_path}/.claude/skills/appstore-connect/compose.swift --locale {locale} --dry-run`, then without `--dry-run`. All-or-nothing: any missing capture / frame / caption is listed in one report and nothing is written. Outputs `docs/store/screenshots/{locale}/{#}_{class}_{id}.png`, exact size.
5. **Verify + lint** — open two outputs with the Read tool (caption legible, bezel aligned, no launch screen); run `asc-lint.sh --locale {locale}` (checks sizes and ≤ 10 per class).
6. **Previews (optional, on request):** record while a flow runs — `xcrun simctl io <udid> recordVideo --codec h264 docs/store/previews/{locale}/{id}.mp4 &` then `scripts/sim.sh flow <FlowName>`; stop the recording with SIGINT. Real footage only (no post-processing beyond trimming); App Store preview lengths 15–30 s. Not automated in v1.
7. **Return:** `ASSETS: {locale} — {N} screenshots ({classes}); plan rows {R}; missing routes {list|none}`.

---

## PRODUCTS — reconcile-first, brownfield-aware

Brownfield projects already carry a `.storekit` and product-ID literals from earlier stories; the op **never asks the user to re-describe what the code declares**. Three sub-ops, chosen by state:

| State | Sub-op |
|---|---|
| no `products.md`, `.storekit` and/or ID literals exist | **IMPORT** → then DIFF |
| no `products.md`, nothing in the project (greenfield) | short `elicit` pass (tiers, periods, trial, family sharing, one-time IAPs, per-locale names) → write spec → **GENERATE** |
| `products.md` exists | **DIFF** (default) · **GENERATE** only with `--regenerate` |

**`products.md` shape** (markdown tables — human-editable, greppable; the model parses it):

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
Duration is ISO-8601 (`P1W`/`P1M`/`P1Y`); level = subscription-group ranking (1 = highest tier); type ∈ consumable / non-consumable / non-renewing.

- **IMPORT** — read the `.storekit` (JSON: `subscriptionGroups[].subscriptions[]` with `productID`, `referenceName`, `recurringSubscriptionPeriod`, `groupNumber`, `familyShareable`, `introductoryOffer`, `localizations`; `products[]` for one-time IAPs) and the Swift product-ID literals; write `products.md` faithfully, one row per product, and set the source-of-truth comment. IDs found in code but not in `.storekit` get a row with `ref name` = `⚠️ code-only`.
- **DIFF** — three ways: spec ↔ `.storekit` ↔ code. Print a table (`product id | in spec | in .storekit | in code | mismatch`) then a **Recommendations** section grounded in Apple's invariants and the IAP-rejection footguns — check each and emit only the ones that apply:
  - mutually-exclusive tiers must share **one subscription group** with distinct **levels** (same level = users can hold both) · every group and every product needs **≥ 1 localization** (and one for every locale in `metadata/`) · every product needs a **review screenshot** (paywall showing that product) · **product IDs are immutable** — a rename in spec vs `.storekit`/code is a new product plus an orphan, say so · **family sharing** cannot be turned off once on · intro/promo offers exist only in ASC, not code — the paywall must not promise a trial the spec lacks · one-time IAP type must match how code consumes it (`consumable` re-buyable vs `non-consumable` restorable) · **"created but never attached to the version"** — the #1 IAP rejection; surfaced as a checklist reminder because it lives only in ASC · paywall must show price/period/auto-renew terms + Privacy/Terms links + Restore (that's `appstore-preflight` Step 5 item 4; cite, don't re-audit).
  - **Return:** `PRODUCTS DIFF: {n} mismatches, {m} recommendations` + the table. `/appstore-preflight` embeds this into its In-App Purchases checklist section.
- **GENERATE** — write the `.storekit` from the spec (greenfield or `--regenerate`), mirroring the existing file's JSON shape when one exists (Xcode's `version {major:4}` schema otherwise), fresh UUIDs for `internalID`, prices left as `0.99` placeholders (prices live in ASC). Say plainly: on first run the existing `.storekit` was authoritative; from now on `products.md` is, and `--regenerate` overwrites.
- The ↔ *live ASC* leg of the diff arrives in v2 with the `asc` client; nothing here talks to ASC.

---

## Hand-offs

- **From `/appstore-preflight`:** its checklist's Media / App Record / IAP `[ ]` lines point here; on re-run preflight calls PRODUCTS DIFF as its IAP step and stamps `[x] verified — asc-lint passed ({date})` on the metadata/screenshot lines when `docs/store/` exists and the lint is clean.
- **To the human:** upload is manual — App Store Connect ▸ App ▸ Version: paste `metadata/{locale}/*.txt`, upload `screenshots/{locale}/` per class in `{order}` order, create products from `products.md` (then **attach them to the version**). Say this at the end of every op.
- **Never:** invent UI (2.3.3 — screenshots are captures of the real build), embellish captures with generated imagery, write anything into ASC, run inside a flywheel, or install a package manager dependency.

## Report

Print the returns of the ops that ran, the lint summary line, and the manual-upload reminder. If any precondition stopped an op, print the fix and stop — a partial artifact set that looks complete is worse than none.
