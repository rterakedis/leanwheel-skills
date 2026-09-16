# StoreKit checks — Guidelines 3.1.1 / 3.1.2

Read only when Step 1 finds StoreKit. Applied as Step 5 item 4.

The paywall must show price + period + auto-renew terms; **functional Privacy Policy and Terms links on the paywall**; a working **Restore Purchases** control for restorable products. Digital goods sold via non-StoreKit checkout → **HIGH**. ⚠️VOLATILE: external purchase links are currently permitted on the **US storefront only** (post-Epic injunction; commission rules still in litigation) — if present, verify storefront-gating and re-check current rules.

**Product reconciliation:** run the `appstore-connect` skill's **PRODUCTS DIFF** op — read only `{skills_path}/.claude/skills/appstore-connect/op-products.md`; Step 1 already found the `.storekit` and StoreKit imports it needs, so that skill's SKILL.md is not required — spec ↔ `.storekit` ↔ Swift product-ID literals, plus its recommendations (group/level structure, missing localizations, missing review screenshots, immutable-ID renames, family-sharing/offer gaps). No `docs/store/products.md` yet → its IMPORT sub-op seeds one from the existing `.storekit`/code first (never ask the user to re-type what the code declares). Each mismatch becomes a `[HIGH][BEHAVIOR]` or `[MEDIUM][BEHAVIOR]` finding; the recommendations flow into the Step 7 IAP section (`render-checklist.sh --storekit yes` keeps it).
