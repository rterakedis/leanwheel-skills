# PRODUCTS — reconcile-first, brownfield-aware

Read by `/appstore-connect products`, and by `/appstore-preflight` when it calls PRODUCTS DIFF
as its IAP step.

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
