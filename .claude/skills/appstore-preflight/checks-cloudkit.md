# CloudKit checks — read only when Step 1 finds CloudKit sync

Applied from Step 4. Its checklist counterpart is the `CloudKit schema` line in
`submission-checklist.template.md`, which `render-checklist.sh --cloudkit yes` keeps.

**CloudKit schema deployed** — severity: **HIGH** (silent post-release failure; Console state isn't in the repo)

iCloud entitlement + `NSPersistentCloudKitContainer` (or a CloudKit-backed `ModelContainer`) present, but **no `initializeCloudKitSchema` call anywhere** → the Development schema is whatever manual testing happened to save. Record types are created lazily on first save, so an entity, attribute, or relationship never exercised on a dev-signed device is absent from Development, is not carried to Production by *Deploy Schema Changes*, and fails to sync for the first real user who creates one. Fix: a DEBUG-only, launch-argument-gated `initializeCloudKitSchema` run on a device (see `testability.md`), then Deploy in the Console
