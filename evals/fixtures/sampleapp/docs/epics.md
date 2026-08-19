# SampleApp — Epics

## Epic 1 — Customer limits
**Goal:** Enforce the free-tier customer cap with an upgrade sheet.

### Story 1.1 — Customer limit service
As an owner, I can't add a 6th customer on the free tier.
- Given 5 customers, when I tap Add, then the upgrade sheet appears.

### Story 1.2 — Upgrade sheet
As an owner, I see pricing and a Restore Purchases button.
- Given the sheet is shown, when I tap Restore, then StoreKit restore runs.
