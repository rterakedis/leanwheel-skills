---
name: appstore-connect
description: Author the App Store Connect inputs for an Apple app as lint-clean, committed artifacts under docs/store/ — framed screenshots at exact store sizes (ASSETS), listing copy per locale (METADATA), and a subscription-group / IAP spec reconciled against the project's .storekit and code (PRODUCTS). Use when the user says "app store connect", "appstore connect", "store listing", "app store screenshots", "store metadata", "release notes", "subscription products", "IAP spec", or after /appstore-preflight hands off. Called by /appstore-preflight for its IAP step (PRODUCTS DIFF).
---

# App Store Connect Skill

**Goal:** Turn the three hardest parts of the submission checklist — screenshots, listing copy, and products — into **declarative artifacts under `docs/store/`** the model drafts from docs it already has (brief, PRD, `docs/ux/EXPERIENCE.md`, shipped stories, the codebase), enforced by a **zero-token linter** and a **deterministic compositor**. Everything is authored *into the repo*; upload is by hand in the App Store Connect web UI (a push client is a v2 item, never inside a flywheel). Same composable-op shape as `docs-sync`: three ops, each gated and idempotent.

**Requires:** an Apple app project (`.xcodeproj` / `.xcworkspace` / app-target `Package.swift`). ASSETS has further preconditions of its own (see [op-assets.md](op-assets.md)). Absent → stop with the one-line fix; never fake a capture.

**Currency note:** Store facts (screenshot classes/sizes in [op-assets.md](op-assets.md), character limits in [op-metadata.md](op-metadata.md)) are current as of **August 2026** and are refreshed by `/refresh-swift` Step 4 alongside `appstore-preflight`'s.

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
             screenshot-captions.txt        # `id: Caption [| Subtitle]` lines — the per-locale strings
    es-MX/   …                              # second locale (the acceptance test for locale-keying)
    copyright.txt  primary_category.txt  [secondary_category.txt]   # inside metadata/, beside the locale dirs
    review_information/  first_name.txt last_name.txt email_address.txt phone_number.txt
                         demo_user.txt notes.txt   [demo_password.txt — only on explicit request; it is committed]
  screenshots/{locale}/  {order}_{class}_{id}.png     # 1_iphone69_home.png, 1_ipadPro13_home.png …
  screenshots.md         # the plan (table) — the human review gate for ASSETS
  frames/                # USER-SUPPLIED bezels: iphone69.png, ipadPro13.png [, {class}-landscape.png, frames.json]
  template.json          # OPTIONAL per-project screenshot styling; absent = the plain default
  products.md            # subscription groups / subscriptions / one-time IAPs
  review-claims.md       # App Review notes claim ledger — rows UNVERIFIED until walked on device (/appstore-preflight Step 7b)
  review-guide.md        # overflow + recording shot list, rendered to PDF for the Guideline 2.1 reply
```

Scripts beside this file (`{skills_path}/.claude/skills/appstore-connect/`, where `{skills_path}` is `.leanwheel/manifest.json` → `skills_path`, or the directory containing this SKILL.md):
- **`compose.swift`** — the deterministic screenshot compositor; invocation and behaviour in [op-assets.md](op-assets.md). Executed, never read.
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

**Each op lives in its own file — read only the one this run needs:**

| Op | Read | What it produces |
|---|---|---|
| METADATA | [op-metadata.md](op-metadata.md) | listing copy per locale under `metadata/{locale}/`, lint-clean |
| ASSETS | [op-assets.md](op-assets.md) | the screenshot plan, captures, and framed store-size PNGs |
| PRODUCTS | [op-products.md](op-products.md) | `products.md` spec reconciled against `.storekit` and code (IMPORT / DIFF / GENERATE) |

A status-only run reads none of them. `/appstore-preflight`'s IAP step reads only `op-products.md`.

---

## Hand-offs

- **From `/appstore-preflight`:** its checklist's Media / App Record / IAP `[ ]` lines point here; on re-run preflight calls PRODUCTS DIFF as its IAP step and stamps `[x] verified — asc-lint passed ({date})` on the metadata/screenshot lines when `docs/store/` exists and the lint is clean.
- **To the human:** upload is manual — App Store Connect ▸ App ▸ Version: paste `metadata/{locale}/*.txt`, upload `screenshots/{locale}/` per class in `{order}` order, create products from `products.md` (then **attach them to the version**). Say this at the end of every op.
- **Never:** invent UI (2.3.3 — screenshots are captures of the real build), embellish captures with generated imagery, write anything into ASC, run inside a flywheel, or install a package manager dependency.

## Report

Print the returns of the ops that ran, the lint summary line, and the manual-upload reminder. If any precondition stopped an op, print the fix and stop — a partial artifact set that looks complete is worse than none.
