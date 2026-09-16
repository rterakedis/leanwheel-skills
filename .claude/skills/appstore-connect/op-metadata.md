# METADATA — listing copy per locale

Read by `/appstore-connect metadata` after SKILL.md Step 0. Character limits below are
store facts refreshed by `/refresh-swift` Step 4.

**Input:** brief / PRD / EXPERIENCE.md / shipped stories (`docs/epics.md` `status: done` rows since the last release, or `git log` since the last tag) / the preflight checklist (URLs, category, detected facts).

1. **Draft** every file for `metadata/{locale}/` (+ root files on first run). Rules that keep review honest and the lint green:
   - **Real features only** — nothing the shipped build doesn't do (Guideline 2.3). Description leads with the outcome, then 3–5 concrete capabilities, then who it's for; no competitor names, no "best"/"#1", no price claims that can go stale.
   - `name` ≤ 30 · `subtitle` ≤ 30 (a benefit, not a tagline) · `keywords` ≤ 100 chars, comma-separated **without spaces**, never repeating a word from the name (Apple already indexes it), no plurals of the same word, no category names · `promotional_text` ≤ 170 (updatable without a build — use it for what's *new*) · `description`/`release_notes` ≤ 4000.
   - `release_notes` = user-facing changes from the shipped stories, plain language, no story IDs.
   - URLs come from the preflight checklist or the user; write only `https://`. `review_information/` is written from the user's answers, except `notes.txt` (≤ 4000), which `/appstore-preflight` Step 7b authors against Apple's eight Guideline 2.1 items. Every navigable claim in it has a `review-claims.md` row and stays `UNVERIFIED` until a human walks it on a device, because copy drafted from source is not evidence (DD-70); `demo_password.txt` only when explicitly asked (say once that it will be committed — the checklist already tells them the demo account must be real and 2FA-free).
2. **Second locale** (`--locale es-MX`): copy the *structure* from `en-US`, translate every file (natural, not literal; keywords re-researched for the locale, not translated word-for-word), and mark anything you couldn't translate confidently with `[TRANSLATE]` so the human sees it. Structure must never be the thing that fails.
3. **Lint** — run `asc-lint.sh` for the locale (network on). Fix ERRORs and re-run until clean; report WARNs.
4. **Return:** `METADATA: {locale} — {N} files written, lint {clean | E errors / W warnings}`.
