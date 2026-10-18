# Content checks — Guidelines 2.5.19 / 4.2 / 1.2

Read only when the scan's `FLAGS` line has `remote-config=yes`, `webview-primary=yes`, or
`ugc=yes` — or the PRD names a Kids Category audience. Applied as Step 5 items 8–10; apply each
item whose trigger holds.

8. **Hidden, dormant, or undocumented features — 2.5.19** (`remote-config`; moved out of 2.3.1, Oct 2026). The flag fires on remote-config SDKs, feature-flag types, and launch-argument / environment reads — any gate that can change what the shipped binary shows. For each gate, ask: **can it turn on in a Release build by a path App Review won't see?**
   - Remote or server-driven flag, a Release-reachable launch argument, `UserDefaults` toggle, secret gesture, or obfuscated code path → **HIGH** (removal and account termination). Fix: compile it out, or ship it on and disclose it in review notes.
   - Compile-time constant that is `false` in Release, with any override inside `#if DEBUG` → fine. Unfinished code that can't be reached isn't a feature reviewers or users can find.
   - A dormant feature planned to switch on later → that's a new build. Its Notes for Review must describe it specifically (2.3.1(a): generic notes get rejected). Never flip it remotely after approval.
9. **Web-wrapper smell — 4.2** (`webview-primary`). If the primary UI is a `WKWebView` of a website, the app must do something Safari can't (native nav, push, offline, widgets) → **HIGH**.
10. **User-generated and AI-generated content — 1.2; kids/age signals** (`ugc`, `webview-primary`, or a Kids Category PRD). Since Oct 2026, 1.2 names **AI content creation apps** alongside social and UGC platforms. The `ugc` flag fires on chat/comment code and on generative APIs (`FoundationModels` sessions, Image Playground). Generated output the user only sees privately doesn't count. Output they can post, share, or publish *through the app* does. Any app in scope needs all four: filtering of objectionable material, a report mechanism with timely response, user blocking, and published contact info. Missing any one → **HIGH**. Failing to put safeguards in place, or to fix violations after Apple's notice, can now count as a Developer Code of Conduct violation (account-level). Also: an unfiltered web view forces 17+/18+, and Kids Category apps need parental gates → **HIGH** where applicable.
