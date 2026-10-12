# App Review packet — reference for Step 7b

<!-- FIELD: DD-70 — learned from a first-submission Guideline 2.1 "Information Needed" rejection on a SwiftUI + CloudKit + StoreKit app, Sept 2026. Protected from refresh passes (DD-66): append / version-scope / retire-with-citation only. -->

A **new app** almost always gets the Guideline 2.1 *Information Needed — New App Submission*
letter first. Answering it after rejection costs a full review cycle (about two weeks). Every
item it asks for is known before submission, so preflight writes the answer up front.

## The eight items (number the notes to match the letter)

1. **Screen recording from a physical device**: launch, the core flow, *every* permission prompt, and the IAP flow.
2. **Devices and OS versions tested.**
3. **Purpose, audience, and value.**
4. **Setup and navigation**, including credentials, or an explicit "no account required".
5. **External services, SDKs, and AI providers**, including on-device Apple ones such as Foundation Models.
6. **Regional differences**, or a statement that there are none.
7. **Regulated-industry or third-party-material authorization**, or "not applicable".
8. **What can be bought, and where the purchase screen is** (exact taps).

Write explicit "not applicable" lines (no account, no user-generated content, no ATT, no regional
differences). Silence reads as an omission.

## Mechanics Apple doesn't advertise

- The App Review **Notes field caps at 4,000 characters** (`asc-lint.sh` enforces this on `review_information/notes.txt`). Put overflow in a PDF guide.
- A reply in Resolution Center takes **one attachment**, so zip the video and the PDF together. **`.mov` is not an accepted type**: export `.mp4`.
- The reply must **itself answer the eight items**. Pointing back to the notes is not enough.
- Regenerate the PDF inside the same script that zips the bundle, so the bundle can't go stale. Headless Chrome renders Markdown→HTML→PDF without pandoc (`"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --print-to-pdf=out.pdf in.html`).

## Claims are verified on a device, not from source

Notes drafted from source can read correctly there and still be false in the running app. In the
source incident, four of them were:

| Claim as drafted | What the running app did |
|---|---|
| "Import from Contacts shows the Contacts prompt" | `CNContactPickerViewController` runs out of process and needs no permission. The prompt lived on a different screen. |
| "Notifications are requested after onboarding" | The request sat behind an overdue-item guard. |
| "Open an item to see field X" | The detail sheet rendered a different notes field. |
| "Units and currency follow the locale" | Distance was hardcoded; currency was split between locale and a hardcoded code. |

This is *verify reachability, not presence* applied to copy that goes to Apple. Rules:

- Every navigable claim gets a row in `docs/store/review-claims.md` and is walked on device before submission, or is left marked `UNVERIFIED`.
- **Permission claims name the exact tap that fires the prompt**, found from the `requestAccess` / `requestAuthorization` / `requestWhenInUseAuthorization` call sites (`grep -rn "request.*Authorization\|requestAccess" --include=*.swift`), not from the screen where the permission is conceptually used. Out-of-process pickers (`CNContactPickerViewController`, `PHPickerViewController`) need no prompt at all.

## Recording the video

- **iOS hides the location permission alert from screen capture**: it records only as a small system placeholder. Notification and camera alerts record normally. Say so in the notes rather than re-shooting.
- **Prompts fire only while the permission is undetermined.** Deleting the app, or Settings → General → Transfer or Reset → Reset Location & Privacy, restores that state. **Turning a permission off in Settings sets it to *denied***, and the app then stays silent. This is a common false fix.
- **Stage the trigger for contextual prompts.** Example: a notification prompt gated on an overdue item needs an item dated yesterday.
- **Don't automate the capture.** A UI-test launch argument that suppresses alerts (good practice for screenshots) hides exactly the prompts Apple wants to see. Record the **submitted Release build** (TestFlight), not a Debug or test build.
- **Multiple clips are fine.** Apple doesn't require one take, so don't make the shot list demand one.
- **Seeded demo data can break a live recording.** Coined, privacy-safe street names fail geocoding or snap to real homes. For recordings, use real, non-residential addresses (parks, civic buildings).
- **CloudKit apps need a clean iCloud account** for a fresh-install recording, or real records sync into the video. Deleting the app does not clear the private database.

## TestFlight purchases don't use the Sandbox Account

- A **TestFlight** install transacts against the Apple ID in **Settings → App Store**, in the sandbox environment. The **Settings → Developer → Sandbox Account** slot applies only to builds run from Xcode.
- So **Clear Purchase History** in App Store Connect can't reset a TestFlight purchase. It works only for sandbox tester accounts.
- **An introductory free trial is used up once per subscription group per account.** After one test purchase, that account never sees the trial offer again.
- Therefore: **record the paywall before any test purchase**, and build from Xcode with a sandbox tester (or a `.storekit` configuration) when you need a purchase state you can reset.

## Resubmission and reply mechanics

<!-- FIELD: DD-78 — learned across three consecutive rejections of one first submission (2.1, 3.1.2(c), 5.1.1(iv)), Sept–Oct 2026. Protected from refresh passes (DD-66). -->

- **Bump `CURRENT_PROJECT_VERSION` on the app *and every extension target*.** Xcode bumps only the
  app. The mismatch warns at build ("The CFBundleVersion of an app extension ('1') must match
  that of its containing parent app ('3')") and **fails at upload**. Test targets don't matter.
- **A rejected version keeps its marketing version.** Only the build number must be unique:
  `1.0 (1)` → `1.0 (2)`, not `1.0.1`.
- **A build that invalidates one beat of the recording doesn't need a re-record.** Ship the
  original plus a short clip of the changed beat, and say in the notes which beat is superseded.
  The bundle script should take any number of videos.
- **Accepted video is `.mp4` / `.avi`**; a zip doesn't launder `.mov`.
- **Product review screenshots may be simulator captures; the 2.1 demo recording may not.** It
  has to be a physical device.
- **Subscription review metadata locks while the product is in review**, so a stale paywall
  screenshot can't be replaced mid-cycle. Attach the corrected image to the Resolution Center
  reply instead and say why.
- **Reply to every cited guideline.** Fix the whole screen, not the sentence Apple quoted: a
  rejection usually cites the visible faults and leaves related ones. Re-run
  `/appstore-preflight` on the touched screen before resubmitting.

## Screens automation can't reach need a manual pass

Permission pre-prompts (`checks-permissions.md`) and any paywall behind a purchase or
onboarding gate are suppressed or unreachable under UI-test and capture runs, so no automated
check, `design-verify` pass, or eval has ever seen them. Both rejections of this kind on the
source project were on screens exactly like that. Walk each on the submitted build, on a device,
before submitting; record the result in `review-claims.md` alongside the notes claims.
