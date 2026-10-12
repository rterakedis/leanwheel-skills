# Data-sharing checks — Guideline 5.1.2

Read only when the scan's `FLAGS` line has `att=yes` or `ai-endpoint=yes`. Applied as Step 5
items 3 and 5; apply each item whose flag is `yes`. The scan has already checked the manifest
side (`tracking-domains-missing`, `tracking-inconsistent`); these are the behaviour side.

3. **ATT — 5.1.2** (`att`). Ad/attribution SDKs or IDFA reads → `requestTrackingAuthorization` flow + usage-description key + manifest tracking flags, and functionality must not be gated on consent. Fingerprinting is never allowed, even with consent. Violation → **HIGH**.
5. **Third-party AI data sharing — 5.1.2(i), since Nov 2025** (`ai-endpoint`). App sends user data to an external AI API (OpenAI/Gemini/Claude endpoints in networking code) → needs explicit, provider-named consent before first send, reflected in the privacy label. Missing → **HIGH**.
