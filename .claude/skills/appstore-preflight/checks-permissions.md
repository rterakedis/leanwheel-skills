# Permission pre-prompt checks — Guideline 5.1.1(iv)

<!-- FIELD: DD-78 — learned from a Guideline 5.1.1(iv) rejection of a SwiftUI app's permission pre-prompt, Oct 2026; Apple's wording is paraphrased from the rejection, not from a primary source. Protected from refresh passes (DD-66): append / version-scope / retire-with-citation only. -->

Read only when Step 5 item 11 finds a permission request call site. A **pre-prompt** is any app
UI that explains a permission before the system alert (a sheet, card, or full screen). It may
explain; it may not steer, and it may not offer a way to skip the system alert.

## Find them (zero-token)

```bash
grep -rnE "request(Access|Authorization|WhenInUseAuthorization|AlwaysAuthorization|FullAccess)|requestPermission|\.requestAuthorization\(" \
  --include="*.swift" . | grep -v "/DerivedData/\|/.build/\|/Pods/\|Tests/"
```

For each hit, read the UI that precedes it (the view that calls into the request, one hop).
No pre-prompt UI, calling the system API directly from a user action = compliant, stop there.

## The three faults

1. **Button copy.** The pre-prompt's button must be neutral — `Continue` or `Next`. Rejected
   copy names the permission or sells it: *enable, allow, turn on, grant, yes, start, activate*,
   or the feature's own name ("Enable Trip Tracking"). → **HIGH**
2. **An exit around the system alert.** Every control on the pre-prompt must lead to the
   system alert: no "Not Now", no "Maybe Later", no close `xmark`, no swipe-to-dismiss
   (`.interactiveDismissDisabled()`), no `dismiss()` that doesn't request. The user may refuse
   *at the system alert*, never before it. → **HIGH**
3. **Trigger.** Present only from a user action on the feature that needs the permission
   (the first tap of the thing that uses location, the first save that schedules a reminder).
   Never from `.task`, `.onAppear`, a tab's first appearance, or launch. An out-of-context
   pre-prompt reads as steering, and once fault 2 is fixed it has no exit at all. → **HIGH**

Fixing only fault 1 or 2 usually leaves fault 3 behind: a Skip button that is removed turns a
polite first-launch sheet into a modal trap. Check all three together.

## Not a pre-prompt

- The system alert itself, and its purpose string (Step 2).
- An out-of-process picker (`PHPickerViewController`, `CNContactPickerViewController`): no
  permission, no pre-prompt.
- A **denied-state** screen ("Location is off — open Settings"). It is reached *after* the
  system alert has been answered, so it may offer a dismiss; its button is `Open Settings`,
  not a request.

## Automation cannot see this screen

Screenshot and UI-test harnesses suppress permission UI on automated runs, so the pre-prompt
never renders under `sim.sh`, `design-verify`, or any seeded flow. Two requirements, both:

- **An opt-in route or launch flag** that reaches it (the way a project's onboarding or paywall
  has one). See `docs/setup/swift/testability.md` → *Permission pre-prompts are invisible to
  automation*.
- **A manual pass on the submitted build** before submission — a checklist item, not an eval,
  because the system alert beyond it cannot be driven anyway.

An un-reachable pre-prompt is not "compliant"; it is **unverified** — record it as a
`[MEDIUM][BEHAVIOR]` finding until a human has walked it.
