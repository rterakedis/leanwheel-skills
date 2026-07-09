---
name: appstore-preflight
description: Audit an iOS/iPadOS SwiftUI project's configuration, privacy declarations, and review-sensitive behaviors against App Store / TestFlight submission requirements. Produces a remediation story plus a non-code submission checklist. Use when the user says "app store preflight", "appstore preflight", "app store readiness", "ready to submit", "testflight readiness", or "publish the app".
---

# App Store Preflight Skill

**Goal:** Scan the Xcode project — Info.plist / build settings, entitlements, privacy manifests, assets, dependencies, and source — for the configuration gaps and guideline footguns that cause upload failures (ITMS errors), TestFlight blocks, and App Store review rejections. Collate findings into a `/dev-story`-ready remediation story, and generate the **non-code submission checklist** (App Store Connect metadata, legal/business items) the developer must complete by hand.

**Requires:** An Apple app project (`.xcodeproj`, `.xcworkspace`, or an app-target `Package.swift`). If absent, stop: "No Apple app project found — nothing to preflight."

**Currency note:** Requirement facts embedded below are current as of **July 2026**. Items marked ⚠️VOLATILE change frequently (litigation, annual SDK mandates) — re-verify against https://developer.apple.com/news/upcoming-requirements/ at submission time rather than trusting this file.

---

## Step 1 — Inventory (zero-token)

```bash
# Project + config surfaces
find . -maxdepth 3 \( -name "*.xcodeproj" -o -name "*.xcworkspace" \) ! -path "*/DerivedData/*"
find . \( -name "Info.plist" -o -name "*.entitlements" -o -name "PrivacyInfo.xcprivacy" \) \
  ! -path "*/DerivedData/*" ! -path "*/.build/*" ! -path "*/Pods/*"
find . -name "Contents.json" -path "*AppIcon*" ! -path "*/DerivedData/*"
find . \( -name "Package.resolved" -o -name "Podfile.lock" \) ! -path "*/DerivedData/*" ! -path "*/.build/*"

# Generated-Info.plist mode? (SwiftUI templates put plist keys in build settings)
grep -l "GENERATE_INFOPLIST_FILE = YES" */project.pbxproj **/project.pbxproj 2>/dev/null
grep -o "INFOPLIST_KEY_[A-Za-z]*" */project.pbxproj **/project.pbxproj 2>/dev/null | sort -u

# Device family + versioning + deployment target
grep -h "TARGETED_DEVICE_FAMILY\|MARKETING_VERSION\|CURRENT_PROJECT_VERSION\|IPHONEOS_DEPLOYMENT_TARGET" \
  */project.pbxproj **/project.pbxproj 2>/dev/null | sort -u
```

**Critical:** most SwiftUI projects use the generated Info.plist — every plist check below must look in **both** the Info.plist file(s) **and** `INFOPLIST_KEY_*` build settings in `project.pbxproj`. A key present in neither is missing.

Note what exists. `docs/ux/`, `docs/prd.md` (feature intel for Step 5), and `.leanwheel/manifest.json` are read only if present.

---

## Step 2 — Purpose Strings (crash + 5.1.1)

The #1 mechanical footgun. A protected API accessed with **no** matching `NS*UsageDescription` = instant runtime kill (→ Guideline 2.1 crash rejection) or ITMS-90683 at upload. A **vague** string ("This app needs camera") = Guideline 5.1.1 rejection. A key present for a capability the app never uses = 5.1.1 over-requesting flag.

Grep source (and note SDKs that link these APIs — Stripe card-scan, Twilio, Firebase ML trip the upload scanner even if the app never calls them):

| Grep pattern (`.swift`) | Required key |
|---|---|
| `AVCaptureDevice\|AVCaptureSession` | NSCameraUsageDescription (+ Microphone if audio capture) |
| `CLLocationManager\|CoreLocation` | NSLocationWhenInUseUsageDescription (Always use → also NSLocationAlwaysAndWhenInUseUsageDescription) |
| `PHPhotoLibrary\|PHAsset` | NSPhotoLibraryUsageDescription (save-only paths → NSPhotoLibraryAddUsageDescription). `PhotosPicker`/`PHPickerViewController` alone needs **no** key |
| `CNContactStore` | NSContactsUsageDescription |
| `EKEventStore` | NSCalendarsFullAccessUsageDescription / NSRemindersFullAccessUsageDescription (iOS 17+ keys; legacy NSCalendars/NSReminders keys only satisfy older targets) |
| `CBCentralManager\|CBPeripheralManager` | NSBluetoothAlwaysUsageDescription |
| `LAContext` + biometrics | NSFaceIDUsageDescription (missing = silent failure, not crash — still flag) |
| `SFSpeechRecognizer` | NSSpeechRecognitionUsageDescription |
| `CMMotionActivityManager\|CMPedometer` | NSMotionUsageDescription |
| `HKHealthStore` | NSHealthShareUsageDescription / NSHealthUpdateUsageDescription |
| `HMHomeManager` | NSHomeKitUsageDescription |
| `NFCTagReaderSession\|NFCNDEFReaderSession` | NFCReaderUsageDescription (no `NS` prefix) |
| `MPMediaLibrary` | NSAppleMusicUsageDescription |
| `ATTrackingManager\|advertisingIdentifier` | NSUserTrackingUsageDescription (see Step 5 ATT) |
| `NWBrowser\|NetService\|Bonjour` | NSLocalNetworkUsageDescription + NSBonjourServices array |
| `AVAudioRecorder\|AVAudioEngine` (input) | NSMicrophoneUsageDescription |

For each finding:
- API used, key missing → **BLOCKER**
- Key present, string < 20 chars or generic (no user-visible reason like "to scan barcodes for price lookup") → **MEDIUM**
- Key present, no matching API usage anywhere → **MEDIUM** (remove it)

---

## Step 3 — Privacy Manifest (`PrivacyInfo.xcprivacy`)

Enforced at upload since May 2024 (ITMS-91053) / Feb 2025 for listed SDKs (ITMS-91061).

**3a. App manifest exists?** `UserDefaults`/`@AppStorage` alone makes it mandatory for virtually every app. No `PrivacyInfo.xcprivacy` in the app target → **BLOCKER**.

**3b. Required-reason APIs declared?** Grep source; each hit needs a matching `NSPrivacyAccessedAPITypes` entry with an approved reason code:

| Grep | Category | Common reason code |
|---|---|---|
| `UserDefaults\|@AppStorage` | `...CategoryUserDefaults` | CA92.1 (own defaults), 1C8F.1 (app group) |
| `creationDate\|modificationDate\|\.stat\b\|fstat\|getattrlist` | `...CategoryFileTimestamp` | C617.1 (in-container files), DDA9.1 (shown to user) |
| `systemUptime\|mach_absolute_time` | `...CategorySystemBootTime` | 35F9.1 (elapsed time) |
| `volumeAvailableCapacity\|systemFreeSize\|statfs` | `...CategoryDiskSpace` | E174.1 (check before write), 85F4.1 (shown to user) |
| `activeInputModes` | `...CategoryActiveKeyboards` | 54BD.1 |

Used-but-undeclared → **BLOCKER** (ITMS-91053 upload rejection).

**3c. Listed SDKs.** Intersect `Package.resolved` / `Podfile.lock` names with Apple's commonly-used-SDK list (Firebase*, Alamofire, Kingfisher, SDWebImage, SnapKit, Lottie, Realm, RxSwift, Charts, GoogleSignIn, FBSDK*, OneSignal, Sentry, Braze, Adjust, AppsFlyer — full list: developer.apple.com/support/third-party-SDK-requirements/). Each match must ship its own manifest (upgrade the dependency — you cannot declare on its behalf) and, if binary-distributed, a code signature → missing = **BLOCKER** (ITMS-91061).

**3d. Tracking consistency.** `NSPrivacyTracking=true` requires `NSPrivacyTrackingDomains`; tracking SDKs present with `NSPrivacyTracking=false` (or no ATT flow) → **HIGH** (5.1.2). iOS blocks requests to declared tracking domains until ATT consent — an app that "works anyway" may be tracking via undeclared domains.

---

## Step 4 — Configuration & Assets

Check each; both plist and `INFOPLIST_KEY_*` locations.

| Check | Rule | Severity if wrong |
|---|---|---|
| `ITSAppUsesNonExemptEncryption` | Absent → every TestFlight build stuck "Missing Compliance" until manually answered. HTTPS/OS-crypto-only apps: set `false` | **HIGH** (TF friction; one-line fix) |
| `CFBundleShortVersionString` / `MARKETING_VERSION` | ≤3 period-separated integers, numeric only, higher than last approved version. `1.0-beta` → upload error | **BLOCKER** if malformed |
| `CFBundleVersion` / `CURRENT_PROJECT_VERSION` | Numeric; must increment per upload (redundant-binary rejection) | **MEDIUM** (advisory — CI often manages) |
| App icon | Asset catalog needs 1024×1024 marketing icon, **no alpha channel** (ITMS-90022/90717). Single-size icon: the one PNG must be 1024², opaque. iOS 18 dark/tinted + iOS 26 `.icon` variants optional | **BLOCKER** if missing/alpha |
| Launch screen | `UILaunchScreen` dict (even empty, or `INFOPLIST_KEY_UILaunchScreen_Generation=YES`) or `UILaunchStoryboardName` required — ITMS-90475 with iPad multitasking; outright mandatory from iOS 27 SDKs | **BLOCKER** |
| iPad orientations | `TARGETED_DEVICE_FAMILY` includes 2 → all four orientations in `~ipad` set unless `UIRequiresFullScreen=YES` (ITMS-90474). ⚠️VOLATILE: `UIRequiresFullScreen` deprecated on iPadOS 26 (will be ignored) — flag its presence; durable answer is all-four + resizable scenes | **BLOCKER** / MEDIUM for the deprecated key |
| `UIRequiredDeviceCapabilities` | Only truly-required values; adding one in an update can never narrow device support (ITMS-90109). Safest: absent or `[arm64]` | **MEDIUM** |
| Entitlements ↔ capabilities | Parse `.entitlements`: `aps-environment`, iCloud containers, app groups, HealthKit, `applesignin`, associated domains each need the capability on the App ID / in the distribution profile (ITMS-90164). `get-task-allow=true` in a distribution archive → upload fail. Push registered in code (or Firebase present) without `aps-environment` → ITMS-90078 warning | **HIGH** (verify-by-hand item — profile state isn't in the repo) |
| ATS | `NSAllowsArbitraryLoads=true` without per-domain exceptions draws review questions and is a security smell | **MEDIUM** |
| Xcode/SDK floor | ⚠️VOLATILE: uploads must be built with iOS 26 SDK / Xcode 26+ (since Apr 28, 2026; re-check annually). Verify local + CI toolchain | **BLOCKER** if toolchain is older |

**Banned / rejection-magnet code (grep, exclude DerivedData/.build/Pods):**

```bash
grep -rn "UIWebView" --include="*.swift" .                       # ITMS-90809 upload fail — also check vendored binaries
grep -rn "dlopen(\|dlsym(\|PrivateFrameworks" --include="*.swift" .  # 2.5.1 private-API patterns (dynamic selectors = flag; static = fine)
grep -rni "lorem ipsum\|coming soon\|placeholder" --include="*.swift" -r Resources/ 2>/dev/null  # 2.1 completeness
grep -rni "beta\|demo\|trial" — check CFBundleDisplayName / INFOPLIST_KEY_CFBundleDisplayName only  # 2.2/2.3 naming
```

Also flag: debug menus reachable in release (`#if DEBUG` gaps around shake/secret-tap handlers), `print`/`NSLog` of tokens or PII (reviewers watch console logs).

---

## Step 5 — Review-Behavior Audit (guideline semantics)

These need judgment, not just grep. Read the relevant source (auth flows, paywall, settings) selectively — do not read the whole codebase.

1. **Account deletion — 5.1.1(v).** If the app has account *creation* (any sign-up, including Sign in with Apple/Google as the only login): there must be an **in-app entry point that initiates full account deletion** (not deactivation, not "email us"). SIWA apps must also call the token-revocation endpoint on delete. Missing → **HIGH**.
2. **Login services — 4.8.** Third-party login SDK present (`GoogleSignIn`, `FBSDKLoginKit`, social OAuth via `ASWebAuthenticationSession`) → an equally-prominent privacy-protective option is required (SIWA is the safe choice; email/password meeting the data-minimization criteria can qualify). Missing → **HIGH**.
3. **ATT — 5.1.2.** Ad/attribution SDKs or IDFA reads → `requestTrackingAuthorization` flow + usage-description key + manifest tracking flags, and functionality must not be gated on consent. Fingerprinting is never allowed, even with consent. Violation → **HIGH**.
4. **Subscriptions/IAP — 3.1.1/3.1.2.** StoreKit present → paywall must show price + period + auto-renew terms; **functional Privacy Policy and Terms links on the paywall**; a working **Restore Purchases** control for restorable products. Digital goods sold via non-StoreKit checkout → **HIGH**. ⚠️VOLATILE: external purchase links are currently permitted on the **US storefront only** (post-Epic injunction; commission rules still in litigation) — if present, verify storefront-gating and re-check current rules.
5. **Third-party AI data sharing — 5.1.2(i), since Nov 2025.** App sends user data to an external AI API (OpenAI/Gemini/Claude endpoints in networking code) → needs explicit, provider-named consent before first send, reflected in the privacy label. Missing → **HIGH**.
6. **In-app privacy policy access — 5.1.1.** A privacy-policy link must be reachable inside the app (settings screen is fine). Missing → **MEDIUM**.
7. **iPad compatibility — 2.4.1.** Every app is reviewed on iPad, **even iPhone-only apps** (compatibility mode). Note as a checklist test item; flag obvious fixed-width/fixed-orientation layouts in a universal app → **MEDIUM**.
8. **Hidden features — 2.3.1.** Remote feature flags that can reveal review-unseen functionality → **HIGH** (account-level enforcement risk). Disclose flag-gated features in review notes instead.
9. **Web-wrapper smell — 4.2.** If the primary UI is a `WKWebView` of a website, the app must do something Safari can't (native nav, push, offline, widgets) → **HIGH**.
10. **Kids/age signals.** UGC or chat without moderation/report/block (1.2), unfiltered web view forcing 17+/18+, Kids Category without parental gates → **HIGH** where applicable.

---

## Step 6 — Triage & Remediation Story

Severity:
- **BLOCKER** — machine-enforced: upload fails (ITMS-*) or TestFlight build unusable
- **HIGH** — near-certain review rejection
- **MEDIUM** — likely reviewer friction or policy drift
- **LOW** — best practice

Scope tags: `[PLIST]` `[MANIFEST]` `[SIGNING]` `[ASSET]` `[CODE]` `[BEHAVIOR]`. Deduplicate per file. Items that are verify-by-hand (provisioning profile contents, App ID capabilities) become checklist items in Step 7, not story ACs.

If zero code/config findings: report "Preflight clean — configuration ready for submission." and continue to Step 7 (the checklist always ships).

Otherwise write `docs/maintainer/appstore-preflight-{YYYY-MM-DD}.md`, mirroring the swift-audit format:

```markdown
---
Status: ready-for-dev
Type: remediation
Generated: {date}
---

# App Store Preflight Remediation — {date}

**Source:** `/appstore-preflight`
**Findings:** {N} total — {B} BLOCKER / {H} HIGH / {M} MEDIUM / {L} LOW

## Acceptance Criteria
<!-- BLOCKER first, then HIGH/MEDIUM/LOW; grouped by scope tag -->
- [ ] [BLOCKER][PLIST] {description} — `{file or build setting}`
- [ ] [HIGH][BEHAVIOR] {description} — `{File.swift}:{line}`

## Tasks
- [ ] Resolve all BLOCKER findings (each prevents upload or TestFlight distribution)
- [ ] Resolve HIGH findings (each is a likely rejection)
- [ ] Re-run `/appstore-preflight` after fixes to confirm clean

## Dev Notes
### Finding Details
{Per finding: what was found (snippet/key), why it fails (ITMS code or guideline number), the exact fix}
```

---

## Step 7 — Submission Checklist (non-code)

Write `docs/maintainer/appstore-submission-checklist.md` (overwrite on re-runs — it's a living gate, not a log). Pre-fill every item the audit can infer: mark `[x] verified — {evidence}`, `[ ]` for human-required items, and **omit sections that don't apply** (no StoreKit → drop the IAP section; note the omission at the top).

```markdown
# App Store Submission Checklist — regenerated {date} by /appstore-preflight

## Account & Legal (one-time)
- [ ] Apple Developer Program enrollment active (individual name vs org: seller name is public)
- [ ] Paid Applications Agreement + banking + tax forms complete — REQUIRED BEFORE any IAP/paid app; products won't even load in sandbox without it
- [ ] EU DSA trader status declared & verified — required to distribute in the EU (since Feb 2025); if monetized, your address/phone/email become PUBLIC on the EU product page (set up a virtual address/VoIP first, or exclude EU)
- [ ] US encryption self-classification report (annual, by Feb 1) if using non-exempt crypto — consult counsel; France declaration if distributing non-exempt crypto there

## App Record (App Store Connect)
- [ ] Bundle ID registered as explicit App ID and matches Xcode — IMMUTABLE after first upload
- [ ] App name (≤30 chars, unique store-wide), subtitle (≤30), primary + secondary category
- [ ] Age rating questionnaire — new 2025 system (4+/9+/13+/16+/18+) must be completed or updates are blocked (deadline was Jan 31, 2026)
- [ ] Content rights declaration answered honestly (third-party content?)
- [ ] Pricing & availability set (base storefront + price; review region list vs DSA/France constraints)
- [ ] Copyright field ("{year} {owner}")

## Required URLs
- [ ] Privacy policy URL — set in App Privacy section AND TestFlight Test Information AND linked inside the app; page must cover actual data types, retention, and every SDK's collection
- [ ] Support URL — page must itself contain a live contact method (FAQ-only fails review); test from a non-dev network
- [ ] (Subscriptions) Terms of Use link in the App Store description or EULA field

## App Privacy (nutrition labels)
- [ ] Data-collection questionnaire matches reality INCLUDING every third-party SDK ({detected SDK list})
- [ ] Cross-checked against Xcode's aggregated privacy report (Organizer → PrivacyReport)

## Media
- [ ] Screenshots: 6.9" iPhone set{+ 13" iPad set if universal} — real UI of THIS build; marketing framing allowed, fabricated UI is not (2.3.3); regenerate after redesigns
- [ ] App previews (optional): actual captured footage only

## App Review Information
- [ ] Demo account: full access, working, NO SMS/2FA (reviewers can't receive it), valid through review + future update reviews
- [ ] Review notes: non-obvious features, hardware/geo dependencies, feature-flag disclosures
- [ ] Contact name/phone/email current

## TestFlight
- [ ] Beta App Description + feedback email + beta privacy policy filled in before external testing
- [ ] First external build passes Beta App Review (subset of full review — approval here ≠ App Store approval)
- [ ] Build cadence plan: TestFlight builds expire after 90 days
- [ ] Export compliance: {status — auto-answered via ITSAppUsesNonExemptEncryption, or answer per build}

## In-App Purchases {omit if no StoreKit}
- [ ] First IAP/subscription products ATTACHED to the version submission (creating them isn't submitting them — #1 IAP rejection)
- [ ] Subscription group has ≥1 localization; review screenshot per product
- [ ] Paywall shows price/period/auto-renew terms + Privacy & Terms links + Restore Purchases (verified in Step 5: {result})

## Signing (verify in Apple Developer portal — not visible in repo)
- [ ] Every entitlement in {detected .entitlements list} has its capability enabled on the App ID and distribution profile
- [ ] Distribution archive uses Release config (get-task-allow=false)

## Submission
- [ ] Version release option chosen (manual release recommended for coordinated launches)
- [ ] Phased release decision (updates only)
- [ ] Final pass on developer.apple.com/news/upcoming-requirements/ for anything newer than this skill's July 2026 data
```

---

## Step 8 — Report

1. Print the summary table:

| Scope | BLOCKER | HIGH | MEDIUM | LOW |
|---|---|---|---|---|
| PLIST / MANIFEST / SIGNING / ASSET / CODE / BEHAVIOR | | | | |

2. State both output paths.
3. Say: "Run `/dev-story docs/maintainer/appstore-preflight-{date}.md` to fix the code/config findings. The checklist items in `appstore-submission-checklist.md` are human actions in App Store Connect — work through them before submitting. Re-run `/appstore-preflight` after fixes to confirm clean."
4. If any ⚠️VOLATILE finding was flagged (external purchase links, SDK-floor, UIRequiresFullScreen), remind the user those rules are in flux and name the one(s) to re-verify.
