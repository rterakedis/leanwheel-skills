# Epic 1 — Customer limits: Test Plan
_Rolled up from 2 story plans on 2026-08-01._

## A. Simulator / local-runnable (do now)
### Flow: Hit the free-tier cap
**Automated — do not re-test:** `CustomerLimitServiceTests`
**Starting state:** 5 customers seeded, free tier.
```bash
scripts/sim.sh launch --uitest --seed heavy --route customers
```
- [x] Tap Add on the 6th customer → upgrade sheet appears
  - already automated: UpgradeSheetFlow asserts exactly this and passes
- [ ] Sheet copy reads naturally at Dynamic Type XL → no truncation [visual-judgment]
  - price line wraps mid-word at XL

## B. Physical-device pass (DEFERRED — requires org developer account)
- [ ] Restore Purchases against the sandbox account — requires: StoreKit on-device
