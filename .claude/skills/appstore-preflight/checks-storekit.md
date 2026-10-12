# StoreKit checks — Guidelines 3.1.1 / 3.1.2

Read only when Step 1 finds StoreKit. Applied as Step 5 item 4.

The paywall must show price + period + auto-renew terms; **functional Privacy Policy and Terms links on the paywall**; a working **Restore Purchases** control for restorable products. Digital goods sold via non-StoreKit checkout → **HIGH**. ⚠️VOLATILE: external purchase links are currently permitted on the **US storefront only** (post-Epic injunction; commission rules still in litigation) — if present, verify storefront-gating and re-check current rules.

**Product reconciliation:** run the `appstore-connect` skill's **PRODUCTS DIFF** op — read only `{skills_path}/.claude/skills/appstore-connect/op-products.md`; Step 1 already found the `.storekit` and StoreKit imports it needs, so that skill's SKILL.md is not required — spec ↔ `.storekit` ↔ Swift product-ID literals, plus its recommendations (group/level structure, missing localizations, missing review screenshots, immutable-ID renames, family-sharing/offer gaps). No `docs/store/products.md` yet → its IMPORT sub-op seeds one from the existing `.storekit`/code first (never ask the user to re-type what the code declares). Each mismatch becomes a `[HIGH][BEHAVIOR]` or `[MEDIUM][BEHAVIOR]` finding; the recommendations flow into the Step 7 IAP section (`render-checklist.sh --storekit yes` keeps it).

## Billed amount must dominate — Guideline 3.1.2(c)

<!-- FIELD: DD-78 — learned from a Guideline 3.1.2(c) rejection of a SwiftUI paywall that rendered the calculated per-month price larger than the billed annual amount, Oct 2026. Protected from refresh passes (DD-66): append / version-scope / retire-with-citation only. -->

The **billed amount** is the most clear and conspicuous pricing element on a subscription
paywall. Every other figure — free trial, introductory price, calculated per-month equivalent,
savings badge — must be visibly subordinate to it in **both size and position**. Font role,
size, weight, colour and placement all count. Apple's finding was that the yearly plan showed a
calculated per-month price "more clearly and conspicuously than the billed amount".

**Check (heuristic is enough — the failure is dramatic).** For each paywall / plan-card view:

```bash
grep -rnE "displayPrice|\.price\b|pricePerMonth|perMonth|monthlyEquivalent|price\s*/\s*(12|52)" \
  --include="*.swift" . | grep -v "/DerivedData/\|/.build/\|/Pods/\|Tests/"
```

Locate where `product.displayPrice` renders and where any *computed* price renders (anything
derived by dividing an annual price, usually through a pricing helper). Compare their font
roles and positions:

- Computed figure has the larger font role (`.title` vs `.caption`), heavier weight, or a more
  prominent position (leading, top, trailing column the eye lands on) → **HIGH** `[BEHAVIOR]`.
- Billed amount rendered at `.caption`/secondary colour while a derived figure is primary → **HIGH**.
- The billed line must also state the period in plain words ("Billed $149.00 once a year").

**Doctrine — don't strip the helpers.** A per-month equivalent and a savings badge are both
*allowed*. They have to be visibly subordinate, not removed. A project that deletes them out of
fear loses legitimate conversion copy; fix the hierarchy instead.

A paywall this check cannot reach under automation (behind a purchase gate or an onboarding
flag) is **unverified** — say so in the Step 7 IAP section rather than passing it.
