# CLAUDE.md — bmad-lite-skills

This repo is a customized fork of [BMAD-LITE](https://github.com/bmad-method/BMAD-LITE). It ships as a Claude Code plugin (`bmad-lite`) via `.claude-plugin/plugin.json`. Skills live in `.claude/skills/` and are registered as `SKILL.md` (uppercase) — the upstream uses `skill.md` (lowercase).

## Purpose

Maintain a curated, customized set of BMAD-LITE skills for use in Claude Code projects. The goal is to selectively pull upstream improvements from BMAD-LITE while preserving intentional local enhancements.

---

## Upstream Sync Workflow

Upstream repo is at `/Users/rterakedis/Git-Repos/BMAD-LITE/` (local clone).

To evaluate and pull upstream changes for a skill:

```bash
# See what changed upstream for a specific skill
diff .claude/skills/<name>/SKILL.md ../BMAD-LITE/skills/<name>/skill.md

# See all skills with upstream divergence
for skill in .claude/skills/*/; do
  name=$(basename "$skill")
  result=$(diff "$skill/SKILL.md" "../BMAD-LITE/skills/$name/skill.md" 2>/dev/null)
  [ -n "$result" ] && echo "DIFFERS: $name"
done
```

When pulling upstream changes, copy content into `SKILL.md` (preserving uppercase filename). Do not blindly overwrite — check against the local customizations documented below.

---

## Local Customizations by Skill

These skills have intentional divergence from upstream. Preserve these when syncing.

### `setup`
Scaffold question 3 changed from a yes/no Apple platform question to a multi-select: "Which Apple platform(s)? (iOS / iPadOS / macOS / none)". Step 3b copies the 6 shared Swift stubs unconditionally when any Apple platform is selected, then adds `ipados-specific.md` if iPadOS is selected and `macos-specific.md` if macOS is selected. Step 3a appends the guardrails block to CLAUDE.md (checks for `## Swift/SwiftUI Guardrails`, not the old `## Modern SwiftUI Patterns` heading).

Added scaffold question 4: "Does this project ship a web surface? (none / web app / Astro / Hugo / other SSG)". Step 3c appends the web guardrails block (`stubs/modern-web.md`, checks for `## Web Guardrails`). Step 3d scaffolds `docs/setup/web/` from `stubs/web/` — shared files (`css-design-system.md`, `accessibility-seo.md`, `anti-patterns.md`) always, plus `astro.md` or `hugo.md` per the answer.

### `check-readiness`
Added **Check 7** (cross-epic runtime dependency analysis), **Check 8** (testing targets derived from architecture, with codification into `CLAUDE.md`), and **Check 9** (UX alignment — conditional on `docs/ux/` existing: design specs final before UI stories, every UI story maps to an EXPERIENCE.md surface, state coverage, token readiness). These checks are not in upstream.

### `code-review`
Additions:
1. Clean-review shortcut line: if no findings, write `Clean review — no patches or deferred items.` instead of an empty checklist.
2. **Epic context update pass** after review: scan for discoveries (constraints, schema details, invariants, "learned the hard way" items) and append them as `## Story {id} Learnings` in `docs/epics/epic-<n>-context.md`.
3. **Pass E — Design Compliance** (conditional on UI diff + `docs/ux/DESIGN.md` or a story Design Contract): off-token values, missing required states, missing dark mode, platform checklist violations, near-duplicate components. Step 2 also reads `docs/setup/web/` rejection criteria on web projects and DESIGN.md tokens for UI diffs.
4. **Component inventory pass**: when a diff ships a new reusable UI component, append it to `docs/ux/components-built.md` (auto-created); `/create-story` injects this inventory into UI stories.
5. **Verify green** step after auto-patch (Step 5): if any patch changed code and a toolchain exists, run a real build + test (`xcodebuild … build test` / `swift build && swift test` / `npm run build && npm test`) before closing the review — a fix verified by reading alone is not resolved. Red = leave finding `[ ]` and Status `in-progress`. Mirrors the `/dev-story` Build & Test Gate.

### `create-story`
Added mandatory **cross-epic runtime dependency check** before writing a story: requires explicitly asking whether the story depends on runtime artifacts (tables, migrations, seed data, endpoints) from a different epic. If yes, note under `### Prerequisites` in Dev Notes and flag sequencing risk to the user.

Added **design contract extraction** for UI stories: reads `docs/ux/DESIGN.md` frontmatter + relevant EXPERIENCE.md sections and embeds tokens, component specs, required states, reuse list (from `docs/ux/components-built.md`), and platform checklist items into a `### Design Contract` section in Dev Notes (template updated to match). Dev sessions never read `docs/ux/` directly. UI stories with no EXPERIENCE.md coverage are flagged as design gaps before writing.

Added **edge-case enumeration + Behavior Contract + Clarification Gate** (fix for thin ACs / downstream rework). Step 3 sets a story complexity (stateful/multi-step vs simple) that scales the rest of the step. Stateful stories draft a `### Behavior Contract` section in Dev Notes (flows, states & valid/illegal transitions, expected outcomes, invariants, enumerated edge cases) *before* writing ACs; every non-obvious edge case must become its own Given/When/Then AC. A new **Clarification Gate** before the write step blocks on *material* ambiguities (forks that would change an AC or task) — the model stops and asks rather than writing speculative ACs — while recording one-default ambiguities as stated assumptions; simple stories skip the gate. In the autonomous flywheel the gate surfaces as a normal Phase 1 human-decision pause. Template (`template.md`) gained the `### Behavior Contract` section as the first Dev Notes block.

### `deferred`
- `d_id` is a required parameter in `LOG-AND-SCHEDULE` (upstream treats it as optional).
- SCHEDULE return message includes `slotted into Story {epic}.{N}` phrasing; upstream uses slightly different wording.

### `dev-story`
Richer task-tracking instructions:
- Explicit direction to check off `[ ]` → `[x]` on Tasks/Subtasks AND Acceptance Criteria during implementation (not after).
- Explicit direction to check off Architecture Compliance Checklist items (if present in Dev Notes) before marking done.
- `Don't modify` list expanded to include Dev Notes prose and References (upstream is more terse).
- **File decomposition enforcement**: Execution instructs proactive decomposition of any touched file that crosses the size/decomposition target in routed guidance (`docs/setup/swift/ui-composition.md` or `docs/setup/web/`), split along responsibility seams (not mechanical line-cutting); a matching DoD checklist item gates it at review. The Swift targets and the two techniques (`extension`-across-files for members, named `private struct` sub-views for layout) plus the sub-view-vs-ViewModel boundary live in `stubs/swift/ui-composition.md` (File-Level Decomposition) and `stubs/swift/anti-patterns.md` (#12 God Views & Data-Owning Sub-Views).

**Build & Test Gate** (not in upstream): a verify-by-running gate added because the loop otherwise verifies code by *reading*, which is where Sonnet-class models regress already-fixed items and re-fix bugs across stories (Swift especially — result builders, macros, actor isolation, `some View` defeat static reasoning). A new **Build & Test Gate** section runs a real toolchain build + test before the story may leave `in-progress`: `xcodebuild … build test` / `swift build && swift test` (mandatory when `docs/setup/swift/` or an Xcode/SPM project exists), `npm run build && npm test` for web, documented command otherwise, or a `manual-required` Debug Log note when no toolchain exists. Red build / failing tests = not done — fix and re-run, or **HALT** (new HALT condition); never set Status `review` over a red build. The result is cited in the Debug Log as the executable regression net. The inline review re-runs the gate after patches (**Re-verify Green**) so a fix is proven green before close. `checklist.md`'s old `## Tests` is now `## Build & Tests`, requiring the build and test runs be *executed and cited this session*, not asserted from reading. Mirrored in standalone `code-review` (**Verify green** step after auto-patch).

Guidance routing and design loop (not in upstream):
- Activation step 4 reads relevant `docs/setup/swift/` files by story topic; step 4b does the same for `docs/setup/web/` (css-design-system / accessibility-seo / astro / hugo / anti-patterns); step 4c makes the story's `### Design Contract` the design source of truth (falls back to reading `docs/ux/` only when a UI story lacks one, and logs the gap).
- On Completion: stateful stories whose `### Behavior Contract` lists invariants run an **evidence-bound invariant verification** step before the inline review — each invariant must be backed by a test or a cited assertion/guard (`file:line`), recorded under `### Invariant Verification`; an invariant with no test and no enforcing code is left `[ ]` UNVERIFIED and fed into review Pass C (never a prose "it holds" claim). Skipped for simple stories / no invariants. Mirrored by a DoD checklist item.
- On Completion: UI stories run **VERIFY** from `skills/design-verify/SKILL.md` (render + screenshot + compare against the contract) before the inline review; results recorded under `### Design Verification` and fed into review triage.
- Inline review gains **Pass E — Design Compliance** (mirrors the standalone code-review pass).

### `epics`
Added **cross-epic runtime dependency scan** step after drafting all epics but before writing. Checks whether any story in an earlier epic requires a runtime artifact (migration, seed data, table, endpoint) from a later epic, and annotates both epics with dependency notes or flags potential reordering.

### `github-tracking`
Added **SYNC** operation: reconciles GitHub issue labels and open/closed state against `status:` frontmatter in every story file. Idempotent; prints a diff table before applying. Invocable as `/github-tracking sync`. Upstream only has `setup` and `backfill`.

### `retrospective`
Expanded from five questions to **seven questions**, with two additions:
- Q2: "What went well?" (reinforcement, distinct from pattern codification)
- Q5: "Did last sprint's conventions hold?" (audit stories against prior retro conventions)

Also added a two-pass deferred item audit:
- **Pass 1**: Scan all story files for `[Defer]` entries not yet logged in `docs/deferred-items.md`; call `LOG-AND-SCHEDULE` for any unlogged items.
- **Pass 2**: Verify all logged deferred items are scheduled into open work in `docs/epics.md`.

### `story-flywheel`
Epic discovery sorts by **epic number embedded in milestone title** (e.g., `"Epic 3 — ..."` → 3), not by GitHub milestone ID. This is intentional: GitHub assigns milestone IDs in creation order, which doesn't reflect intended epic sequence. Upstream sorts by milestone ID.

Also uses `gh api` with `--jq` for more precise issue filtering within a milestone (rather than `gh issue list` piped to `first`).

Phase 4 checkpoint includes a **TESTING PLAN** section (between DEFERRED ITEMS and UNRESOLVED ITEMS): concrete manual steps derived from the story's ACs and changed code — tap/click paths, API calls, edge cases. Writes "none — no user-visible surface changed." for pure refactors or migrations.

### `ux`
Added a **Content site (SSG) preset** (Astro/Hugo) alongside the web-app and Apple presets: typography-first token probing, CSS custom property token names, content-model → layout mapping in IA, a mandatory **Content & Performance** section in EXPERIENCE.md (CWV target + per-page-type JS budget with named/justified islands), and SEO/meta as design decisions. `checklist.md` gained a matching section 7 (Content Site / SSG); platform question text mentions SSGs explicitly.

---

### `refresh-swift`
New skill with no upstream equivalent. Researches current Swift/SwiftUI best practices from gold-standard sources (Hacking with Swift, Swift with Majid, SwiftLee, Apple WWDC docs, Point-Free) and updates both the project's `docs/setup/swift/` sectioned reference docs and the skills repo stubs. Triggered via `/refresh-swift`. Scope is iOS 18 through current stable release — hard-excludes pre-release APIs. After updating guidance, offers to chain into `/swift-audit`.

### `swift-audit`
New skill with no upstream equivalent. Audits planning docs (`architecture.md`, `prd.md`, `epics.md`), story files, and Swift source code against the guidance in `docs/setup/swift/`. Produces a single remediation story file at `docs/epics/swift-audit-{date}.md` with one AC per finding, ready for `/dev-story`. Triggered via `/swift-audit`. Requires `docs/setup/swift/` to exist. Also checks hardcoded `Color(red:)`/`Color(hex:)` usage against `docs/ux/DESIGN.md` tokens when that file exists.

### `refresh-web`
New skill with no upstream equivalent. Mirror of `/refresh-swift` for the web surface: researches current web platform / CSS / Astro / Hugo best practices from gold-standard sources (web.dev, MDN, Astro docs, Hugo docs, CSS-Tricks, Smashing, WAI) and updates `docs/setup/web/` plus the `stubs/web/` originals and the `modern-web.md` guardrails stub. Scope: Baseline widely-available platform features + current stable Astro/Hugo majors; hard-excludes experimental features. Offers to chain into `/web-audit`.

### `web-audit`
New skill with no upstream equivalent. Mirror of `/swift-audit` for web projects: audits planning docs, story files, templates, stylesheets, and markup against `docs/setup/web/` guidance and `docs/ux/DESIGN.md` tokens. Framework-aware (Astro vs Hugo grep sets). Writes a remediation story to `docs/maintainer/web-audit-{date}.md`, one AC per finding. Requires `docs/setup/web/` to exist.

### `design-verify`
New skill with no upstream equivalent. Composable visual-verification step: renders changed UI (simulator screenshots light/dark + Dynamic Type on Apple; dev server screenshots at mobile/desktop widths on web) and compares against the story's Design Contract / `docs/ux/` specs. Writes findings to `### Design Verification` in the story file. Invoked inline by `/dev-story` for UI stories; degrades to a manual checklist when no rendering tooling is available. Directly invocable as `/design-verify`.

---

## Web Guidance Stubs (`setup/stubs/web/`)

Mirror of the Swift stub system for web/SSG projects. Five sectioned reference files (`css-design-system.md`, `astro.md`, `hugo.md`, `accessibility-seo.md`, `anti-patterns.md`) plus the `modern-web.md` guardrails block (~50 lines, appended to project CLAUDE.md). Copied into projects by `/setup` Step 3d, routed into dev sessions by `/dev-story` step 4b, used as rejection criteria by `/code-review` and `/web-audit`, kept current by `/refresh-web`.

---

## Skills Identical to Upstream

No local changes — safe to overwrite from upstream on sync:

`architecture`, `correct-course`, `discover`, `investigate`, `prd`, `quick-dev`, `security-review`, `status`

(`setup` and `ux` were previously in this list; both now carry local customizations documented above.)

---

## Repo Structure

```
.claude/
  skills/
    <skill-name>/
      SKILL.md        # skill prompt (uppercase — plugin convention)
.claude-plugin/
  plugin.json         # plugin manifest (name, description, author)
```

## Conventions

- Skill files are always named `SKILL.md` (uppercase). Upstream uses `skill.md`.
- No `settings.json` in `.claude/` — this repo is a plugin, not a project config.
- Do not add project-level docs (`docs/`, story files, etc.) — this repo ships skills only.
