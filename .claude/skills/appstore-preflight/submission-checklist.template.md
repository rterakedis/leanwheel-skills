# App Store Submission Checklist — regenerated {date} by /appstore-preflight

## Account & Legal (one-time)
- [ ] Apple Developer Program enrollment active (individual name vs org: seller name is public)
- [ ] Paid Applications Agreement + banking + tax forms complete — REQUIRED BEFORE any IAP/paid app; products won't even load in sandbox without it
- [ ] EU DSA trader status declared & verified — required to distribute in the EU; if monetized, your address/phone/email become PUBLIC on the EU product page (set up a virtual address/VoIP first, or exclude EU)
- [ ] US encryption self-classification report (annual, by Feb 1) if using non-exempt crypto — consult counsel; France declaration if distributing non-exempt crypto there

## App Record (App Store Connect)
- [ ] Bundle ID registered as explicit App ID and matches Xcode — IMMUTABLE after first upload
- [ ] App name (≤30 chars, unique store-wide), subtitle (≤30), primary + secondary category
- [ ] Age rating questionnaire — current system (4+/9+/13+/16+/18+) must be completed or updates are blocked
- [ ] ⚠️VOLATILE: Social-media capability question in the age-rating questionnaire (places the app in the Time Allowance category for Social Media) is **required for new versions/updates and notarization** — answer honestly, don't skip
- [ ] Content rights declaration answered honestly (third-party content?)
- [ ] Pricing & availability set (base storefront + price; review region list vs DSA/France constraints)
- [ ] Availability on Apple silicon Macs and Apple Vision Pro decided (iPhone/iPad apps are offered there by default; opt out in App Store Connect if touch-, camera- or navigation-dependent)
- [ ] Copyright field ("{year} {owner}")

## Required URLs
- [ ] Privacy policy URL — set in App Privacy section AND TestFlight Test Information AND linked inside the app; page must cover actual data types, retention, and every SDK's collection
- [ ] Support URL — page must itself contain a live contact method (FAQ-only fails review); test from a non-dev network
- [ ] (Subscriptions) Terms of Use link in the App Store description or EULA field

## App Privacy (nutrition labels)
- [ ] Data-collection questionnaire matches reality INCLUDING every third-party SDK ({detected SDK list})
- [ ] Cross-checked against Xcode's aggregated privacy report (Organizer → PrivacyReport)

## Media
- [ ] Screenshots: 6.9" iPhone set{+ 13" iPad set if universal} — real UI of THIS build; marketing framing allowed, fabricated UI is not (2.3.3); regenerate after redesigns. **More than half of each device's set, in each localization, must show the app in use** — never only login, splash or title art; overlays must not hide the UI
- [ ] App previews (optional): actual captured footage only

## App Review Information
- [ ] Demo account: full access, working, NO SMS/2FA (reviewers can't receive it — if a code is unavoidable, put a working one in Notes or the review waits 3–5 business days on a call), valid through review + future update reviews; one per account type; sensitive/regulated apps may ship a demonstration mode instead
- [ ] Regulated field or third-party material: licence / clearance / permission documents attached BEFORE submitting (`review-packet.md` item 7), or "not applicable" stated in notes
- [ ] Review notes answer Apple's eight Guideline 2.1 items, numbered (Step 7b) — {`[x] verified — asc-lint clean, 0 UNVERIFIED claims ({date})` or `[ ] {N} UNVERIFIED claims in docs/store/review-claims.md`}
- [ ] Physical-device screen recording (Release build; launch, core flow, every permission prompt, IAP flow) + PDF guide zipped as ONE `.mp4`+`.pdf` attachment, ready for the 2.1 reply
- [ ] Contact name/phone/email current
- [ ] Tested on a physical device per supported platform, incl. iPad compatibility mode for iPhone-only apps; models + OS versions listed in notes item 2
- [ ] Permission pre-prompts walked by hand on the submitted build: neutral button, no way around the system alert, shown only after a user action on the feature (`checks-permissions.md` — automation can't reach them)

## TestFlight
- [ ] Beta App Description + feedback email + beta privacy policy filled in before external testing
- [ ] First external build passes Beta App Review (subset of full review — approval here ≠ App Store approval)
- [ ] Build cadence plan: TestFlight builds expire after 90 days
- [ ] {omit if no StoreKit} Paywall recorded BEFORE any TestFlight test purchase — TestFlight buys with the Settings → App Store Apple ID (not the Sandbox Account), can't be reset by Clear Purchase History, and uses up the free trial for that account (`review-packet.md`)
- [ ] Export compliance: {status — auto-answered via ITSAppUsesNonExemptEncryption, or answer per build}
- [ ] CloudKit schema {omit if no CloudKit}: `--init-cloudkit-schema` run on a debug build on a **physical device signed into iCloud** since the last model change, then **Deploy Schema Changes** (Development → Production) in the CloudKit Console — spot-check that Production lists every record type in the model

## In-App Purchases {omit if no StoreKit}
- [ ] First IAP/subscription products ATTACHED to the version submission (creating them isn't submitting them — #1 IAP rejection)
- [ ] Subscription group has ≥1 localization; review screenshot per product
- [ ] `docs/store/products.md` reconciled — PRODUCTS DIFF: {n mismatches, m recommendations — or "not run: no .storekit"}; create products in ASC from that spec (`/appstore-connect products`)
- [ ] Subscriptions behind an account: a demo account with an EXPIRED subscription in App Review Information, so the reviewer can walk the whole purchase flow
- [ ] Each product tested in the sandbox and in **Ready to Submit / Ready for Review** state; any storefront or device restriction stated in review notes
- [ ] Paywall shows price/period/auto-renew terms + Privacy & Terms links + Restore Purchases (verified in Step 5: {result})
- [ ] Paywall's **billed amount** is the most prominent price (size and position); per-month equivalent, trial, and savings badge are subordinate (Guideline 3.1.2(c); `checks-storekit.md` — verified in Step 5: {result})

## Signing (verify in Apple Developer portal — not visible in repo)
- [ ] Every entitlement in {detected .entitlements list} has its capability enabled on the App ID and distribution profile
- [ ] Distribution archive uses Release config (get-task-allow=false)

## Submission
- [ ] Build number unique and identical on the app **and every extension** target; resubmission after rejection keeps the marketing version (`review-packet.md`)
- [ ] Version release option chosen (manual release recommended for coordinated launches)
- [ ] Phased release decision (updates only)
- [ ] After submitting: answer App Review by **replying**, not resubmitting, unless the build changed (`review-lifecycle.md`); screenshots lock at Waiting for Review
- [ ] Final pass on developer.apple.com/news/upcoming-requirements/ for anything newer than this skill's July 2026 data
