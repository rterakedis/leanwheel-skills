# Account checks — Guidelines 5.1.1(v) / 4.8

Read only when the scan's `FLAGS` line has `account-creation=yes` or `third-party-login=yes`.
Applied as Step 5 items 1–2; apply each item whose flag is `yes`. Read the auth flow and the
settings screen selectively, not the whole codebase.

1. **Account deletion — 5.1.1(v)** (`account-creation`). If the app has account *creation* (any sign-up, including Sign in with Apple/Google as the only login): there must be an **in-app entry point that initiates full account deletion** (not deactivation, not "email us"). SIWA apps must also call the token-revocation endpoint on delete. Missing → **HIGH**.
2. **Login services — 4.8** (`third-party-login`). Third-party login SDK present (`GoogleSignIn`, `FBSDKLoginKit`, social OAuth via `ASWebAuthenticationSession`) → an equally-prominent privacy-protective option is required (SIWA is the safe choice; email/password meeting the data-minimization criteria can qualify). Missing → **HIGH**.
