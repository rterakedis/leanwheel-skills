# Content checks — Guidelines 2.3.1 / 4.2 / 1.2

Read only when the scan's `FLAGS` line has `remote-config=yes`, `webview-primary=yes`, or
`ugc=yes` — or the PRD names a Kids Category audience. Applied as Step 5 items 8–10; apply each
item whose trigger holds.

8. **Hidden features — 2.3.1** (`remote-config`). Remote feature flags that can reveal review-unseen functionality → **HIGH** (account-level enforcement risk). Disclose flag-gated features in review notes instead.
9. **Web-wrapper smell — 4.2** (`webview-primary`). If the primary UI is a `WKWebView` of a website, the app must do something Safari can't (native nav, push, offline, widgets) → **HIGH**.
10. **Kids/age signals** (`ugc`, `webview-primary`, or a Kids Category PRD). UGC or chat without moderation/report/block (1.2), unfiltered web view forcing 17+/18+, Kids Category without parental gates → **HIGH** where applicable.
