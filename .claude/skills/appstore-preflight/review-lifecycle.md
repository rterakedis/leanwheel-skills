# After you submit — reference for a submission in review, rejected, or removed

Read only when the user has a submission in App Review, a rejection or removal message, or asks
about expediting, appealing, or a review call. Research knowledge (DD-82): every line is from
Apple's App Review help — https://developer.apple.com/help/app-review/ (read Nov 2026) — and is
refreshed by `/refresh-swift` Step 4. Rejection-earned mechanics live in `review-packet.md`
(a `<!-- FIELD -->` file); where the two overlap, that file wins.

## Status and timing

- Apple's target: 50% of submissions reviewed within 24 h, 90% within 48 h. Longer for apps with
  little review history, submissions needing documentation, and new entitlements or regulated
  content — the three things a complete Notes field and attached documents shorten.
- **Waiting for Review**: some fields are still editable and items can be removed, but
  **screenshots and previews are locked**. **In Review**: cancel only. **Unresolved Issues**:
  one or more items were rejected.
- Status changes can be delivered by App Store Connect webhooks instead of polling.

## Reply, or resubmit?

Resubmitting starts a **new** review and ends the thread: App Review can no longer answer the
earlier message, and an open appeal is closed.

| Situation | Do |
|---|---|
| Apple asked for more information, nothing else open | **Reply** in App Store Connect |
| Fix is metadata or server-side (e.g. activating demo credentials) | Make the change, then **reply** |
| The message offers a Bug Fix Submission and you want it | **Reply** accepting |
| You are appealing | Appeal form; **don't resubmit** |
| The build itself was rejected and is fixed | Upload a new build and **resubmit** |
| Some items rejected, others accepted | Remove the rejected items and **resubmit** |

Never resubmit with a cited issue unresolved: same outcome, later.

## Bug Fix Submission

Updates to an already-approved app only. Eligible when the rejection message opens with
"Bug Fix Submissions: The issues we've identified below are eligible to be resolved on your next
update." Reply asking for this submission to be approved; do not resubmit. Every deferred issue
must be fixed in the next update, and **cannot be deferred twice**. No note = not eligible.

## Asking App Review

- Use **Reply to App Review**; a specialist who knows the app answers. Name the exact feature,
  guideline or step. Not for appeals, expedites, or other developers' apps.
- A **call** can be requested in the same thread after a reply: give time zone and preferred
  language, keep the App Review Information contact details current. Typically 3–5 business days.
- **Before** submitting, a 30-minute "Meet with Apple" App Review appointment (Tue/Thu, local
  hours) answers how a guideline applies. Informational only: no pre-approval, no expedite.

## Expedited review

Only for a submission already sent, and only for genuine urgency. Put the reason in the Notes
field **at submission** — the critical bug, or the event, its date, and the app's tie to it —
then file https://developer.apple.com/contact/app-store/?topic=expedite. For events, also
schedule the release ahead of time.

## Appeal (App Review Board)

- Reply to the rejection first; appeal only if that doesn't resolve it.
- **One appeal per app**, covering every guideline cited, each answered point by point with how
  the app satisfies it. "Please take another look" is the incomplete form.
- Not for information requests, status checks, expedites, or after you fixed and resubmitted.

## Removal and App Store Improvements

- Live-app issue: typically **14 days** to submit a compliant update; safety or legal issues
  remove immediately; an incompatible concept is removed for good.
- Common causes: hidden features, a **post-approval change — including a server-side one — that
  introduces a violation** (`checks-content.md` item 8), user reports, takedown requests.
- App Store Improvements: no update in **three years** *and* minimal downloads over a rolling
  12 months → notice, then **90 days** to submit an update. **Apps that crash on launch are
  removed immediately.** A removed app keeps its name and keeps working for existing users.
