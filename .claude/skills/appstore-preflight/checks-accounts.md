# Account checks — Guidelines 5.1.1(v) / 4.8

Read only when the scan's `FLAGS` line has `account-creation=yes` or `third-party-login=yes`.
Applied as Step 5 items 1–2; apply each item whose flag is `yes`. Read the auth flow and the
settings screen selectively, not the whole codebase.

1. **Account deletion — 5.1.1(v)** (`account-creation`). If the app has account *creation* (any sign-up, including Sign in with Apple/Google as the only login): there must be an **in-app entry point that initiates full account deletion** (not deactivation, not "email us"). SIWA apps must also call the token-revocation endpoint on delete. Missing → **HIGH**. Apple's 5.1.1(v) reference page adds — each a **HIGH** when it applies, **MEDIUM** when only the copy is missing:
   - **Guest / auto-created accounts count**, and so does an account created on the web: the app still needs the in-app entry point.
   - **Easy to find** (account settings), and deletion covers the whole record **including user-generated content shared with others**. Offered to every user, not only GDPR/CCPA regions.
   - **No support detour**: no phone call, email, or chat flow to finish (highly regulated industries, 5.1.1(ix), excepted). A web hand-off must link **directly** to the deletion page. Re-authentication and a confirm step are fine.
   - **Say what happens**: how long deletion takes if not immediate (and confirm when done), what is legally retained, and — with auto-renewable subscriptions — that **billing continues through Apple until cancelled**, with `showManageSubscriptions` or `https://apps.apple.com/account/subscriptions/`. Scheduled-at-expiry deletion is allowed only beside an immediate option.
2. **Login services — 4.8** (`third-party-login`). Third-party login SDK present (`GoogleSignIn`, `FBSDKLoginKit`, social OAuth via `ASWebAuthenticationSession`) → an equally-prominent privacy-protective option is required (SIWA is the safe choice; email/password meeting the data-minimization criteria can qualify). Missing → **HIGH**.
