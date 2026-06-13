---
name: design-verify
description: Visually verify implemented UI against docs/ux/DESIGN.md tokens and EXPERIENCE.md states by building and observing the running app or site. Called by /dev-story for UI stories; directly invocable as /design-verify to check the current working tree.
---

# Design Verify Skill

**Goal:** Confirm that user-visible UI changes actually match the design contract — by rendering them, not by re-reading the code. Code review catches wrong logic; this catches wrong *pixels*: off-token colors, missing dark mode, broken states, truncated type.

**When:** Invoked inline by `/dev-story` after DoD passes for any story that changed user-visible UI, or directly via `/design-verify`. Skip entirely (report "no user-visible surface changed") for pure backend/refactor diffs.

**Requires:** `docs/ux/DESIGN.md` and/or `docs/ux/EXPERIENCE.md`. If neither exists, fall back to the platform guardrails checklist only (`docs/setup/swift/` or `docs/setup/web/`).

---

## Step 1 — Scope

1. Identify changed surfaces: from the story's File List (or `git diff --name-only` when standalone), list the screens/pages/components a user can see.
2. From `docs/ux/EXPERIENCE.md`, pull the required states for each changed surface (empty / loading / error / offline, per the State Patterns section).
3. From `docs/ux/DESIGN.md` frontmatter, pull the tokens the changed surfaces consume.
4. If the story has a `### Design Contract` section in Dev Notes, that is the checklist source — don't re-derive.

## Step 2 — Render

Pick the first option that works; degrade gracefully. Never block the story on missing tooling.

**Apple platform:**
```bash
# Build for simulator, launch, screenshot
xcodebuild -scheme {scheme} -destination 'platform=iOS Simulator,name=iPhone 16' build
xcrun simctl boot "iPhone 16" 2>/dev/null; xcrun simctl launch booted {bundle_id}
xcrun simctl io booted screenshot /tmp/design-verify-light.png
# Dark mode pass
xcrun simctl ui booted appearance dark && xcrun simctl io booted screenshot /tmp/design-verify-dark.png
xcrun simctl ui booted appearance light
```
Also capture one screenshot with Dynamic Type at an accessibility size:
`xcrun simctl ui booted content_size accessibility-extra-large` (reset after).
Navigate to the changed surface first if it isn't the launch screen — use the app's deep link/URL scheme if one exists; otherwise screenshot what is reachable and note the limitation.

**Web / SSG:**
```bash
# Astro: npm run dev | Hugo: hugo server
# then screenshot changed pages at two widths (mobile ~390px, desktop ~1280px)
```
Use whatever browser/screenshot tooling the session has (browser MCP, preview tool, Playwright if installed: `npx playwright screenshot --viewport-size=390,844 {url} /tmp/dv-mobile.png`). Capture both `prefers-color-scheme` values if the site supports dark mode.

If the site uses a custom font, check for visible font swap: load a changed page with cache disabled (or first visit in a fresh browser context) and compare a screenshot at first paint vs. after load — text changing glyphs or shifting position is a HIGH finding (guidance requires `font-display: optional` + metric-matched fallback). If tooling can't capture first paint, add "hard-reload with cache disabled and watch body text for flash/reflow" to the manual checklist.

**Nothing available:** Don't fake it. Write a **MANUAL VERIFICATION** checklist instead (concrete tap/click paths per surface and state, derived from the ACs) and mark the verification `manual-required`.

## Step 3 — Compare

For each captured surface, check against the contract. Read the screenshots (you can view images) and answer:

| Check | Source |
|---|---|
| Colors match tokens (no near-miss hex drift); both appearances correct | DESIGN.md `colors` |
| Spacing/radii consistent with scale (no visibly off-grid gaps) | DESIGN.md `spacing` / `rounded` |
| Type roles and hierarchy as specced; no truncation at large type / 200% zoom | DESIGN.md `typography` |
| Required states render (empty / loading / error) — drive them where feasible | EXPERIENCE.md State Patterns |
| Layout holds at both sizes (mobile/desktop or iPhone/iPad as in scope) | EXPERIENCE.md platform section |
| Components reuse the established inventory, not near-duplicates | `docs/ux/components-built.md` |
| Platform checklist items visible in the capture (safe areas, tap targets / focus visibility) | HIG checklist / web guardrails |

States that can't be driven from the UI (e.g., a server error) get a one-line note in the manual checklist rather than silent omission.

## Step 4 — Record and Hand Back

Write results into the story file under `### Design Verification` (create if missing):

```markdown
### Design Verification
- Surfaces verified: {list} ({N} screenshots: light/dark × sizes)
- [x] {check that passed}
- [ ] [HIGH/MEDIUM/LOW] {mismatch} — expected {token/state from contract}, observed {what rendered}
- Manual verification required: {none | list of steps}
```

Severity: `HIGH` = wrong/missing state, unreadable text, broken layout, missing dark mode on a load-bearing surface. `MEDIUM` = off-token value, spacing drift. `LOW` = polish nits.

**When invoked from `/dev-story`:** hand findings to the inline review's triage — mismatches become `patch` or `decision-needed` findings like any other. The story does not reach `done` with an unresolved HIGH design finding.

**When standalone:** report the table, fix `patch`-grade mismatches on request.
