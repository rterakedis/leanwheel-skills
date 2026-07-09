# CLAUDE.md — leanwheel-skills

This repo is a lean, token-efficient port and simplification of the [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) for Claude Code. It ships as a Claude Code plugin (`leanwheel`) via `.claude-plugin/plugin.json`. Skills live in `.claude/skills/` and are registered as `SKILL.md` (uppercase) — the upstream uses `skill.md` (lowercase) and an entirely different file structure (activation ceremony, TOML customization tiers, JIT step files) that this repo deliberately does not carry over.

## Purpose

Maintain a curated, token-conscious set of BMAD skills for use in Claude Code projects. The goal is to periodically check the upstream BMAD Method for new capabilities or fixes worth porting — as *ideas*, never as direct file copies — while preserving the structural simplifications and local enhancements documented below. See [guide/comparison.md](guide/comparison.md) for the full cut/added rationale.

---

## Committing and Pushing

Use `scripts/commit-push.sh` instead of running individual git commands — one Bash call, zero reasoning overhead:

```bash
# Stage modified tracked files only (default — safest)
bash scripts/commit-push.sh "your commit message"

# Stage specific files
bash scripts/commit-push.sh "your commit message" path/to/file.md another/file.md

# Stage everything including untracked (use with care)
bash scripts/commit-push.sh "your commit message" --all
```

The script stages, commits (with the Co-Authored-By trailer), and pushes to the current branch in one invocation. Do not fall back to the multi-command git workflow in this repo.

---

## Upstream Sync Workflow

There is no maintained fork of upstream — clone the original framework directly when you want to check for new capabilities:

```bash
git clone https://github.com/bmad-code-org/BMAD-METHOD /tmp/BMAD-METHOD
```

Upstream's skill files don't structurally match this repo's (different filenames, activation ceremony, TOML customization tiers, JIT step-file loading), so a mechanical `diff` isn't useful here. Instead, hand the comparison to an AI assistant with a prompt that leads with this repo's token-minimization philosophy, so it filters for genuine capability gains rather than re-importing ceremony this repo intentionally cut. Example prompt:

```
I maintain leanwheel-skills, a token-efficient port of the BMAD Method for Claude Code.
It deliberately strips: the per-invocation activation ceremony, three-tier TOML
customization, agent persona overhead, and JIT step-file loading — replacing them with
plain-English rules in CLAUDE.md and single-pass inline skill files. Full rationale in
guide/comparison.md and guide/features.md in this repo.

Compare /tmp/BMAD-METHOD (upstream) against .claude/skills/ in this repo. For each
upstream skill, tell me:
1. Any genuinely new capability or bugfix not present here
2. Whether porting it would require re-adding ceremony/ infrastructure this repo cut
   (if so, propose a lean equivalent instead of importing it wholesale)
3. Which local skill file(s) would need to change, and a one-paragraph plan — not a
   direct file copy
Skip anything that's purely structural/ceremonial with no functional difference.
```

Treat the output as a worklist, not a patch — port the *idea* into the equivalent `SKILL.md`, checking it against the local customizations documented below first.

---

## Local Customizations by Skill

These skills have intentional divergence from upstream. Preserve these when syncing.

### `setup`
Scaffold question 3 changed from a yes/no Apple platform question to a multi-select: "Which Apple platform(s)? (iOS / iPadOS / macOS / none)". Step 3b copies the 7 shared Swift stubs (incl. `testability.md` — seed scenarios, launch-argument contract, XCUITest smoke posture) unconditionally when any Apple platform is selected, then adds `ipados-specific.md` if iPadOS is selected and `macos-specific.md` if macOS is selected. Step 3a appends the guardrails block to CLAUDE.md (checks for `## Swift/SwiftUI Guardrails`, not the old `## Modern SwiftUI Patterns` heading).

Added scaffold question 4: "Does this project ship a web surface? (none / web app / Astro / Hugo / other SSG)". Step 3c appends the web guardrails block (`stubs/modern-web.md`, checks for `## Web Guardrails`). Step 3d scaffolds `docs/setup/web/` from `stubs/web/` — shared files (`css-design-system.md`, `accessibility-seo.md`, `anti-patterns.md`) always, plus `astro.md` or `hugo.md` per the answer.

Added agentic-engineering scaffolding: Step 1 also creates `docs/evals/` + `docs/metrics/` (from `stubs/evals/` and `stubs/metrics/`). New **Step 3e** copies the deterministic guardrail hooks (`stubs/hooks/*.sh`) into `.claude/hooks/` and chmod +x. **Step 4** now merges the hook wiring from `stubs/hooks/hooks-settings.json` into `.claude/settings.json` (PreToolUse/PostToolUse) alongside the skills `add-dir` startup hook. **Step 5** writes `.leanwheel/manifest.json` (skills_path, surfaces, asset flags) for `/upgrade-project` to sync against. Subagents need no scaffolding — they ship plugin-level in `agents/` (the plugin-standard location at repo root).

### `check-readiness`
Added **Check 7** (cross-epic runtime dependency analysis), **Check 8** (testing targets derived from architecture, with codification into `CLAUDE.md`, plus — on Apple app projects — verification that Epic 1 contains the testability-foundation story; missing = blocker + LOG-AND-SCHEDULE), **Check 9** (UX alignment — conditional on `docs/ux/` existing: design specs final before UI stories, every UI story maps to an EXPERIENCE.md surface, state coverage, token readiness), and **Check 10** (pre-mortem — plan-level red-teaming: assume the shipped project failed at month three, work backwards to 5–8 causes grounded in the actual PRD/architecture/epics, classify each as addressed / unaddressed-material → blocker + LOG-AND-SCHEDULE / unaddressed-speculative → warning). Checks 7–9 are not in upstream. Check 10 is the lean fold-in of upstream's pre-mortem, which ships as one method in `bmad-advanced-elicitation`'s CSV-served interactive menu — the menu/registry infrastructure is not ported, just the motion, run inside the gate where the three planning docs are already in context. Division of labor: `/forge-idea` pressure-tests the *idea*, Check 10 pressure-tests the *plan*.

Output additionally **stamps** `<!-- readiness-check: {date} — {b} blockers, {w} warnings -->` below the H1 of `docs/epics.md` (updated in place on re-runs) — the deterministic marker `/next` routes on.

### `code-review`
Additions:
1. Clean-review shortcut line: if no findings, write `Clean review — no patches or deferred items.` instead of an empty checklist.
2. **Epic context update pass** after review: scan for discoveries (constraints, schema details, invariants, "learned the hard way" items) and append them as `## Story {id} Learnings` in `docs/epics/epic-<n>-context.md`.
3. **Pass E — Design Compliance** (conditional on UI diff + `docs/ux/DESIGN.md` or a story Design Contract): off-token values, missing required states, missing dark mode, platform checklist violations, near-duplicate components, and **dark patterns** (pre-checked paid/consent opt-ins, defaults pre-selecting the higher-cost choice, fake/endowed progress, urgency with no real deadline, confirmshaming copy, decoy pricing — checked against EXPERIENCE.md's `## Engagement & Persuasion`; a lever not backed by an honest entry is HIGH severity). Step 2 also reads `docs/setup/web/` rejection criteria on web projects and DESIGN.md tokens for UI diffs.
4. **Component inventory pass**: when a diff ships a new reusable UI component, append it to `docs/ux/components-built.md` (auto-created); `/create-story` injects this inventory into UI stories.
5. **Verify green** step after auto-patch (Step 5): if any patch changed code and a toolchain exists, run a real build + test (`xcodebuild … build test` / `swift build && swift test` / `npm run build && npm test`) before closing the review — a fix verified by reading alone is not resolved. Red = leave finding `[ ]` and Status `in-progress`. Mirrors the `/dev-story` Build & Test Gate. Verify green also runs the `evals` RUN op (a failing eval is a regression that blocks closing).
6. **Eval Scorecard** (SCORE op): emits a structured pass/fail line per dimension (correctness · edge-cases · ac-coverage · design · security → GATE) — no extra model calls, just scoring the passes already run. Feeds the flywheel checkpoint and ledger.
7. **Ledger**: appends a `code-review` line to `docs/metrics/flywheel-ledger.jsonl` when `docs/metrics/` exists.
8. **Guidance-drift flag** (doc-feedback Gap B): when the codebase consistently/intentionally contradicts `docs/setup/swift|web` guidance, calls the `docs-sync` **DRIFT** op to emit a `GUIDANCE DRIFT:` advisory recommending `/refresh-swift` / `/refresh-web` — never mutating `docs/setup/*` (external-sourced canon). (Mechanics live in the [`docs-sync`](#docs-sync) skill.)

### `create-story`
Added mandatory **cross-epic runtime dependency check** before writing a story: requires explicitly asking whether the story depends on runtime artifacts (tables, migrations, seed data, endpoints) from a different epic. If yes, note under `### Prerequisites` in Dev Notes and flag sequencing risk to the user.

Added **design contract extraction** for UI stories: reads `docs/ux/DESIGN.md` frontmatter + relevant EXPERIENCE.md sections and embeds tokens, component specs, required states, reuse list (from `docs/ux/components-built.md`), and platform checklist items into a `### Design Contract` section in Dev Notes (template updated to match). Dev sessions never read `docs/ux/` directly. UI stories with no EXPERIENCE.md coverage are flagged as design gaps before writing.

Added **edge-case enumeration + Behavior Contract + Clarification Gate** (fix for thin ACs / downstream rework). Step 3 sets a story complexity (stateful/multi-step vs simple) that scales the rest of the step. Stateful stories draft a `### Behavior Contract` section in Dev Notes (flows, states & valid/illegal transitions, expected outcomes, invariants, enumerated edge cases) *before* writing ACs; every non-obvious edge case must become its own Given/When/Then AC. A new **Clarification Gate** before the write step blocks on *material* ambiguities (forks that would change an AC or task) — the model stops and asks rather than writing speculative ACs — while recording one-default ambiguities as stated assumptions; simple stories skip the gate. In the autonomous flywheel the gate surfaces as a normal Phase 1 human-decision pause. Template (`template.md`) gained the `### Behavior Contract` section as the first Dev Notes block.

Added **eval seeding**: After Writing, if `docs/evals/` exists, runs the `evals` BUILD op to derive `type: command` regression cases from the ACs/invariants (referencing tests dev-story will write), making the story's intended behavior part of the cumulative regression net.

**Pinned story frontmatter format** (determinism fix): `template.md` now declares `status:` (and `title:`) as **YAML frontmatter** fields — the single machine-readable source of truth read by github-tracking / `gh-track.sh` / the flywheels — and explicitly forbids restating Status as a `**Status:**` body line. Root cause: the old template put `github_issue` in frontmatter but Status in the body, leaving the format underspecified, so create-story emitted *three* different shapes across one project (full-YAML, frontmatter-less `**bold**` headers, canonical) — and SYNC, which reads frontmatter `status:`, silently skipped the body-status variants. create-story / dev-story / code-review status-update steps now all write `status:` in frontmatter. `gh-track.sh` additionally tolerates the legacy `**Status:**`/`**GitHub Issue:** #N` body format on read (normalizing `✅ Done` → `done`) to recover pre-existing files without hand-editing.

### `product-brief`
New skill, lean port of upstream `bmad-brainstorming` + `bmad-product-brief` **merged into one skill** rather than two — diverge (brainstorm, only when the user has no formed idea yet) and distill (write `docs/project/brief.md`) are sequential phases of one motion, not independent workflows; flow-detected like `/ux`'s Create/Update/Validate. Fills a real gap: `/prd` Step 1 was "describe the product, one prompt," with nothing upstream of it for idea generation. Diverge motion: stance choice (Facilitator/Creative Partner/Ideate-for-me), 3-4 techniques picked from a small inline list (no CSV/script catalog — that's upstream infrastructure this repo intentionally doesn't carry over), explicit Converge phase kept separate from generation. Distill motion mirrors `/prd`'s existing Fast/Coaching-path + `[ASSUMPTION]`-tagging shape, writes `docs/project/brief.md` (+ `brief-addendum.md` for overflow detail that doesn't belong in a 1-2 page brief). Ends by offering `/forge-idea` as a pressure-test before finalizing. `/prd` Activation now reads `docs/project/brief.md` silently if present, and Step 1 confirms the brief back instead of asking the user to describe the product cold.

### `forge-idea`
New skill, lean port of upstream `bmad-forge-idea`. Standalone adversarial idea-validation skill — invocable directly or chained from the end of `/product-brief`. Pressure-tests a formed idea via persona cross-examination (one outside-skeptic voice per turn: competitor/buyer/domain expert/support engineer, generated inline rather than from a persona-pool registry) until it resolves to one of three exit states, all valid: **Hardened** (writes `docs/project/forged-idea-{slug}.md` — decisions/rejections/reasons only, no prose recap), **Killed** (idea didn't hold up — said plainly, no artifact, loops back to `/product-brief`'s Diverge flow), **Clearer** (no artifact, just sharper understanding). On Hardened with real changes to an existing brief, offers to loop back to `/product-brief` to fold in the findings; on Hardened with no brief yet, offers to write one; on Hardened with nothing to change, reminds the user to start a **new session** and run `/ux` (UI-based) or `/prd` (no UI) next — a fresh context window rather than carrying the brainstorm/pressure-test conversation forward. Drops upstream's memlog-script persistence and the wax-seal HTML artifact (pure ceremony, no functional value for this fork).

### `research`
New skill, lean port that **merges upstream's three near-identical research variants** (`bmad-technical-research`, `bmad-domain-research`, `bmad-market-research`) into one skill with a type selector — the three upstream skills share one mechanic (parallel web search per facet → cited findings → synthesis) with only the facet checklist differing, so porting them as three separate `SKILL.md` files would triple maintenance for zero behavioral difference. Asks technical/domain/market + topic, runs the matching facet list (reused from upstream's groupings, condensed), writes cited findings directly to `docs/project/research/{type}-{topic-slug}-{date}.md` as it goes, closes with a short synthesis (key findings, confidence/gaps, recommendation) rather than upstream's 12-section narrative-report scaffold. Drops the per-step `[C] Continue` HALT-and-reread gating (collapsed to one checkpoint between scoping and execution) and the TOML/JIT step-file layer.

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
- Activation step 4 reads relevant `docs/setup/swift/` files by story topic (incl. `testability.md` for stories touching model entities, user-facing views, or launch behavior); step 4b does the same for `docs/setup/web/` (css-design-system / accessibility-seo / astro / hugo / anti-patterns); step 4c makes the story's `### Design Contract` the design source of truth (falls back to reading `docs/ux/` only when a UI story lacks one, and logs the gap).
- Execution keeps testability current in the same task (seed-scenario updates on model changes, accessibility identifiers on new views — DoD-gated via `checklist.md`).
- On Completion: stateful stories whose `### Behavior Contract` lists invariants run an **evidence-bound invariant verification** step before the inline review — each invariant must be backed by a test or a cited assertion/guard (`file:line`), recorded under `### Invariant Verification`; an invariant with no test and no enforcing code is left `[ ]` UNVERIFIED and fed into review Pass C (never a prose "it holds" claim). Skipped for simple stories / no invariants. Mirrored by a DoD checklist item.
- On Completion: UI stories run **VERIFY** from `skills/design-verify/SKILL.md` (render + screenshot + compare against the contract) before the inline review; results recorded under `### Design Verification` and fed into review triage.
- Inline review gains **Pass E — Design Compliance** (mirrors the standalone code-review pass).

Added to the Build & Test Gate: runs the `evals` RUN op (cumulative `command` regression set across stories — a failing case is treated like a red build) and the BUILD op (registers the story's new tests as cases). On Completion writes a `dev-story` line to `docs/metrics/flywheel-ledger.jsonl`.

**Operational doc sync** (human-guide feedback): On-Completion Wrap-Up step (the "All resolved" path) calls the `docs-sync` **OPERATIONAL** op with the story's final changed-file list — keeping the human stand-up / run-it / database guides current when an infra-shaped file changed, zero-cost otherwise. Surfaced via a `DOCS UPDATED:` field in the `lw-story-developer` report contract (captured by story-/epic-flywheel), a `docs_updated` ledger field, and a DoD checklist item. The human-readable counterpart to the architecture-promotion feedback (which serves the LLM's planning). Mechanics + the infra-signal table live in the [`docs-sync`](#docs-sync) skill (single source of truth, also called by `quick-dev`).

### `epics`
Added **cross-epic runtime dependency scan** step after drafting all epics but before writing. Checks whether any story in an earlier epic requires a runtime artifact (migration, seed data, table, endpoint) from a later epic, and annotates both epics with dependency notes or flags potential reordering.

Added **testability foundation story** requirement (Apple app projects): Epic 1 must include an early story (post-scaffold, pre-first-feature) shipping the `docs/setup/swift/testability.md` foundation — `SeedScenario` registry, `--seed`/`--uitest`/`--reset` launch-argument contract with in-memory store isolation, accessibility-identifier convention, and one XCUITest smoke target. Enforced by `check-readiness` Check 8 (missing = blocker + LOG-AND-SCHEDULE); kept current per-story by `dev-story` (seed updates + identifiers in the same task, DoD-gated); consumed by `design-verify` (seed-arg launches to render required states) and `e2e-tests` (tests reach state via `--seed`, never via tap-through setup).

### `github-tracking`
Added **SYNC** operation: reconciles GitHub issue labels and open/closed state against `status:` frontmatter in every story file. Idempotent; prints a diff table before applying. Invocable as `/github-tracking sync`. Upstream only has `setup` and `backfill`.

Also **decomposed the deterministic label mechanics into `scripts/gh-track.sh`** (project-scaffolded like `commit-push.sh`). TRANSITION/CLOSE-ISSUE/SYNC are now one-line shell calls (`gh-track.sh transition|close|sync`); the skill keeps only the *policy* (when to transition) and the interactive SETUP/BACKFILL/SYNC confirm gates. The script moves an issue between mutually-exclusive status labels and **strips every stale status label** in one deterministic step — fixing the in-model label drift (e.g. `backlog` left beside `ready-for-dev`) and saving the per-transition token cost of view→parse→edit→verify. `sync` is dry-run by default, `--apply` to execute; degrades to `skip: gh unavailable` (exit 0) so a flywheel is never blocked. Skills fall back to raw `gh` when the script is absent (older un-upgraded projects). Scaffolded by `/setup` Step 3f, refreshed by `/upgrade-project`, called by the flywheels (epic-flywheel drives transitions itself rather than trusting cold subagents).

### `retrospective`
Expanded from five questions to **seven questions**, with two additions:
- Q2: "What went well?" (reinforcement, distinct from pattern codification)
- Q5: "Did last sprint's conventions hold?" (audit stories against prior retro conventions)

Also added a two-pass deferred item audit:
- **Pass 1**: Scan all story files for `[Defer]` entries not yet logged in `docs/deferred-items.md`; call `LOG-AND-SCHEDULE` for any unlogged items.
- **Pass 2**: Verify all logged deferred items are scheduled into open work in `docs/epics.md`.

Strengthened the **PRD / Architecture Sync Check** to also call the `docs-sync` **PROMOTE** op (doc-feedback Gap A, manual path): promotes durable project-canonical learnings from `docs/epics/epic-{N}-context.md` into `docs/architecture.md` (idempotent — safe to run alongside epic-flywheel's boundary PROMOTE). Never edits `docs/setup/*` (records a refresh action item instead). Mechanics in the [`docs-sync`](#docs-sync) skill.

Output additionally **stamps** `<!-- retro: epic {N} — {date} -->` below the H1 of `docs/epics.md` (one line per epic, idempotent) — the deterministic marker `/next` routes on — and the closing Report now points at `/epic-flywheel {N+1}` in a fresh session instead of `/create-story`.

### `story-flywheel`
Epic discovery sorts by **epic number embedded in milestone title** (e.g., `"Epic 3 — ..."` → 3), not by GitHub milestone ID. This is intentional: GitHub assigns milestone IDs in creation order, which doesn't reflect intended epic sequence. Upstream sorts by milestone ID.

Also uses `gh api` with `--jq` for more precise issue filtering within a milestone (rather than `gh issue list` piped to `first`).

Phase 4 checkpoint includes a **TESTING PLAN** section (between DEFERRED ITEMS and UNRESOLVED ITEMS): concrete manual steps derived from the story's ACs and changed code — tap/click paths, API calls, edge cases. Writes "none — no user-visible surface changed." for pure refactors or migrations.

**Subagent Delegation & Model Routing** (not in upstream): the default mode delegates each phase to a leanwheel subagent (`lw-story-creator`, `lw-story-developer`, `lw-story-reviewer` in `agents/`) via the Agent tool. Two Pro-plan wins: **automatic model routing** (no manual `/model` switching) and **context isolation** (each phase's heavy doc/code reading runs in a throwaway subagent window; the orchestrating thread only accumulates short structured reports). Routing is Conserve-Opus baseline with a dynamic Swift exception: create-story=Sonnet, dev-story=**Sonnet on Python/web but Opus on Swift** (`swift_project` = `docs/setup/swift/` exists OR an `.xcodeproj`/`.xcworkspace`/`Package.swift` present), code-review=Sonnet. The flywheel passes a per-spawn `model: opus` override only for Phase 2 on Swift. Because dev-story already runs an **inline** review, Phase 3 spawns a separate reviewer only when there are unresolved items / a FAIL gate / a security-sensitive story — otherwise it carries the Phase 2 findings straight to the checkpoint (saves an extra review's tokens). Human touch-points collapse to three: Phase-1 clarification surfacing, the Phase-4 checkpoint, the epic-boundary gate; an opt-in **auto-pilot** ("auto-continue on clean stories") advances past checkpoints that are fully green with no unresolved items while always stopping on red/HALT. **Fallback** (subagents unavailable): the old **MODEL SWITCH GATE** hard-stops, Swift-only, documented under "Fallback: Manual Model Switching." Rationale for Swift→Opus even under Conserve-Opus: a Sonnet Swift dev-story pass tends to fail the Build & Test Gate and loop, and each failed `xcodebuild` retry costs more than one accurate Opus pass — so Opus is the token-conserving choice there; on Python/web Sonnet passes first-try often enough that Opus is overspend. Phase 4 checkpoint gained a **VERIFICATION** line (Build & Test · evals P/T · rubric gate · invariants · iterations) and writes a story-level roll-up to `docs/metrics/flywheel-ledger.jsonl`.

### `ux`
Added a **Content site (SSG) preset** (Astro/Hugo) alongside the web-app and Apple presets: typography-first token probing, CSS custom property token names, content-model → layout mapping in IA, a mandatory **Content & Performance** section in EXPERIENCE.md (CWV target + per-page-type JS budget with named/justified islands), and SEO/meta as design decisions. `checklist.md` gained a matching section 7 (Content Site / SSG); platform question text mentions SSGs explicitly.

Web app preset requires **delta-only DESIGN.md tokens** when a named UI system (shadcn/MUI) is in scope — only the brand-layer override values, not a restatement of the system's defaults (upstream demonstrates this inheritance discipline; the local skill previously left it implicit). Finalize gained a **mock coverage confirmation** sub-step: walk every IA surface, classify mocked vs. spine-only, ask once whether any spine-only surface needs a visual reference, and log the answer either way — closes a gap where a surface could fall through Finalize with no deliberate mocked/spine-only decision recorded.

Added an **Engagement & Persuasion** design decision (no upstream equivalent): Step 4 Discovery gains an *engagement-levers* probe over high-leverage flows only (onboarding, forms, upgrade/paywall, destructive actions) applying five behavioral principles — smart defaults, goal gradient, reciprocity, loss framing, contrast/anchoring — each paired with a mandatory **honesty check** (how it aligns the user's interest with the business's). Dark-pattern variants (pre-checked paid/consent opt-ins, fake/endowed progress, manufactured urgency, confirmshaming copy, decoy pricing) are named and rejected, not applied. Recorded in a new `## Engagement & Persuasion` section in `experience-template.md` (required, or explicit N/A), validated by `checklist.md` section 8 (renumbered Bloat→9, Shape→10) and its section-10 required-sections list. The design-time counterpart to `code-review` Pass E's dark-pattern check and the `guard-dark-pattern.sh` write-time advisory hook. Sourced from UX-psychology principles the maintainer wanted baked into every design rather than left to whoever designs that day.

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
New skill with no upstream equivalent. Composable visual-verification step: renders changed UI (simulator screenshots light/dark + Dynamic Type on Apple; dev server screenshots at mobile/desktop widths on web) and compares against the story's Design Contract / `docs/ux/` specs. On projects with the testability foundation, launches with `--seed` arguments (`empty`/`edge`/`heavy`) to render the states the contract requires rather than whatever state the simulator holds. Writes findings to `### Design Verification` in the story file. Invoked inline by `/dev-story` for UI stories; degrades to a manual checklist when no rendering tooling is available. Directly invocable as `/design-verify`.

### `evals`
New skill with no upstream equivalent. Composable, **stack-agnostic** regression-net + scoring layer (the "evals" half of verification the Build & Test Gate can't cover). A case is `type: command` (a shell command + expected result — **zero model tokens**, works for `swift test`/`xcodebuild`/`pytest`/`npm test`/`playwright`/`curl`) or `type: judge` (LM-as-judge, **opt-in + token-flagged**, only for genuinely non-deterministic behavior). Cases accumulate in `docs/evals/epic-{n}.md`, versioned with the project. Ops: **BUILD** (create-story derives cases from ACs/invariants), **RUN** (dev-story Build & Test Gate + code-review Verify-green run the cumulative `command` set — a failing case is a regression that blocks just like a red build), **SCORE** (code-review emits a pass/fail rubric line from passes it already ran). Directly invocable as `/evals` (zero-token) or `/evals --judge`. The `command`-default design is the highest-leverage, lowest-cost eval mechanism for the Pro plan.

### `docs-sync`
New composable skill with no upstream equivalent — the **single source of truth for documentation feedback** (closes the gap where dev/review discoveries never flowed back into the project's docs). A skill, **not a subagent** (it runs inline in the caller's context, which already holds the changed-file list / story context — a fresh subagent window would just re-derive it; subagents stay reserved for the three heavy phase-runners). Three ops, each gated + idempotent (zero model cost when there's nothing to do):
- **OPERATIONAL** — from a changed-file list, maintains and **grows** the **human operational guides** in the `docs/setup/` (stand up from scratch), `docs/maintainer/` (operate it), and `docs/sql/` (database) areas. Deterministically gated on an infra-signal set (dependency manifests, `.env`/config, migrations/schema, scripts, Dockerfile/CI/deploy, new service entrypoints). May **create new focused topical pages** within an existing area (e.g. `docs/setup/stripe.md`, `docs/maintainer/background-jobs.md`) and wires each into that area's `index.md` hub — the goal is human-consumable, link-tied docs, not one fat file. Auto-writes but grounds edits in the actual diff/CI/code and tags inferred runbook steps `⚠️ inferred — verify`. Never writes `docs/setup/swift|web/` (refresh-owned coding guidance) and never creates the top-level area directories themselves (stays silent if an area is absent — that's `/setup`'s job). Called by **dev-story** (On-Completion) and **quick-dev** (Phase 4).
- **PROMOTE** — promotes durable project-canonical learnings (schema realities, new/changed services & integrations, cross-cutting invariants, architectural decisions) from `docs/epics/epic-{N}-context.md` into `docs/architecture.md` (the LLM's planning doc), idempotently. Called by **epic-flywheel** (boundary gate 4c) and **retrospective**.
- **DRIFT** — flag-only: when the codebase consistently contradicts `docs/setup/swift|web/` guidance, emits a `/refresh-swift|web` advisory; never mutates `docs/setup/*`. Called by **code-review**.

Directly invocable as `/docs-sync` (runs OPERATIONAL over the working tree). Three doc audiences kept deliberately separate: human operational guides (OPERATIONAL writes), LLM planning doc (PROMOTE writes), external-sourced coding guidance (neither writes — DRIFT only flags; `/refresh-*` owns it). Surfaced through a `docs_updated` ledger field and a dev-story DoD item.

**Model routing — runs on Haiku via the `lw-docs-sync` subagent** (see [Flywheel subagents](#flywheel-subagents) and the routing memory). OPERATIONAL/PROMOTE are mechanical, grounded-in-diff prose and must never inherit the dev model (**Opus on Swift**). Since a skill can't pick its own model, the `lw-story-developer` subagent does **not** run docs-sync inline — it reports `INFRA TOUCHED: yes/no`, and the **orchestrator** (story-/epic-flywheel) spawns `lw-docs-sync` (Haiku) after the dev phase (OPERATIONAL, via the story's File List) and at the epic boundary / retrospective (PROMOTE). Main-session callers (`quick-dev`, standalone `dev-story`, `/docs-sync`) spawn it directly. DRIFT stays inline (one advisory line — cheaper than a spawn). Inline execution remains the fallback when subagents are unavailable.

### `upgrade-project`
New skill with no upstream equivalent. Brings an existing leanwheel project up to the latest skills/stubs/hooks/framework — the recurring sync to `/setup`'s first-run. **Detection-based** (works on projects scaffolded before manifests existed): scans for missing assets (hooks, evals/metrics dirs, hook wiring, CLAUDE.md guardrail blocks) and stub drift, classifying each as ADD / REFRESH / **CONFLICT** / OK. The REFRESH-vs-CONFLICT test uses git provenance of `{skills_path}` — if a project stub hashes to any historical committed version it was never locally edited → safe REFRESH; otherwise it's a CONFLICT, surfaced for manual merge and **never auto-overwritten**. Previews a plan, applies only ADD/REFRESH on confirmation, writes `.leanwheel/manifest.json` going forward. Token-safe (small reads + git/hash compares, no model-heavy work). Never touches planning docs or story files. Triggered via `/upgrade-project` ("upgrade project", "sync leanwheel").

### `epic-flywheel`
New skill with no upstream equivalent. The autonomous, epic-scoped layer *above* `story-flywheel` — drives a whole epic from "not started" to "implemented, reviewed, verified together" with minimal steering. Reuses story-flywheel's three subagents and per-phase model routing (does not duplicate the table). Adds five things story-flywheel lacks: (1) **granular commit-per-step** (create → commit → dev → commit → review+patch → commit) so a bad story is bisectable/unravel-able rather than buried in one squash — uses the project's `scripts/commit-push.sh` if present, else plain git, and requires up-front commit authorization; (2) **within-epic auto-advance** on fully-green stories (the per-story Build & Test / evals / invariant gates still HALT on a real compounding bug — only the *manual* test pass is deferred); (3) a real **Epic Boundary Gate** that runs a whole-project build+test, the cumulative `evals` RUN across all epics, an invariant-verification sweep, and a two-pass deferred sweep — **any failure HALTs and asks for help, never starts the next epic**; (4) continuous deferred-item **re-homing** (orphan check at the boundary); (4c) **architecture promotion** (doc-feedback Gap A): a zero-token boundary step calling the `docs-sync` **PROMOTE** op — harvests project-canonical learnings from `docs/epics/epic-{N}-context.md` and appends the durable ones to `docs/architecture.md` (idempotent) so the next epic plans against live docs instead of a stale architecture; never touches `docs/setup/*`; (5) a **rolled-up, LLM-deduplicated Test Plan** written to `docs/epics/epic-{N}-test-plan.md`, merging per-story TESTING PLANs into end-to-end flows + edge cases and **classifying every test as simulator/local-runnable vs physical-device-required** (camera, APNs push, Face ID, sensors, org-account-gated provisioning). Physical-device items also accrue to a persistent cross-epic `docs/testing/physical-device-backlog.md` so they resurface when an org developer account lands — directly addresses the user's current inability to test on physical hardware. The boundary report **always surfaces a mandatory retrospective reminder** (recommended flow: run the simulator test plan → then `/retrospective` for the epic → then start the next epic); skipping retro requires an explicit confirmation. Token posture: every boundary gate is zero-token (shell commands + short recorded-block reads); the only model-heavy step is the once-per-epic dedup over plan text. Per-story TESTING PLANs are stashed to a scratch `docs/epics/.epic-{N}-test-plans.md` so the orchestrator never holds all plans in context at once. Triggered via `/epic-flywheel` ("epic flywheel", "run the whole epic", "flywheel the epic").

### `harvest-findings`
New composable skill with no upstream equivalent — closes the manual-test-pass loop that `/epic-flywheel`'s boundary Test Plan opens. During the manual test pass the tester records findings as inline bulleted sub-lists under each scenario/step in `docs/epics/epic-{N}-test-plan.md`; this skill harvests them, captures them durably, triages them by *kind* and *disposition*, and turns the corrective in-scope ones into a new remediation story — **without ever reopening a `status: done` story** (done stories are immutable; fixes land in the new story `{N}.{last+1}`). **Findings are not assumed to be bugs** — the deterministic parse (an *indented, non-checkbox* `-`/`*` bullet under a `- [ ]` step) harvests anything the tester noted, and Step 2 classifies each finding's **kind** (bug / tweak / enhancement / question) alongside its **disposition** ([in-scope] / [defer]). Kind drives routing: **bug + tweak** are corrective (an in-scope one becomes a remediation AC); **enhancement** is additive (always scheduled as a backlog candidate / flagged for `/correct-course`, *never* a remediation AC — avoids scope creep mislabeled as a fix); **question** is surfaced for a human decision, never auto-storied. Four steps: (1) **Harvest** — read-only parse, collecting `{scenario-id, scenario-title, finding-text}`; stops with "No test findings to harvest" if none. (2) **Capture to `docs/epics.md` FIRST** (durability before authoring) — writes a checklisted `### Epic {N} — Post-Test Findings (harvested {date})` block, each finding tagged kind · disposition; idempotent per test-pass date. (3) **Route by kind** — authors `create-story` for `docs/epics/{N}-{last+1}-post-test-findings.md` (one AC per *corrective* in-scope finding, phrased to the kind, each linked to its source scenario) + appends the epics.md row + `github-tracking` CREATE-ISSUE; routes deferred bug/tweak and *all* enhancements through `deferred`/LOG-AND-SCHEDULE (never into the new story); surfaces questions; the story's DoD requires the docs-sync **OPERATIONAL** reconcile of `architecture.md`/`prd.md`/`ux/*` and the Step-4 test-plan reset before it can close. (4) **Reset** — strips the tester's inline finding bullets from the test plan (scenarios/steps intact) so it's clean for re-test. Composes `deferred`, `create-story`, `github-tracking`, `docs-sync` rather than reimplementing them. Directly invocable as `/harvest-findings {N}`; wired into `/epic-flywheel`'s boundary report (the "harvest" option, between test and retro) and `/retrospective` (before the deferred sweep). Token posture: cheap parses/edits + one delegated create-story call; idempotent.

### `e2e-tests`
New skill, lean port of upstream `bmad-qa-generate-e2e-tests` (previously listed in guide/comparison.md as deliberately cut — reintroduced because all local testing was *forward-looking*: `evals` BUILD derives cases from ACs as stories are written, leaving brownfield code, pre-evals features, and the manual test plan with no automation path). Retro-fits automated API/E2E tests onto already-built features. Three target modes: named feature, **test-plan conversion** (automates simulator/local-runnable scenarios from `docs/epics/epic-{N}-test-plan.md`, marking each `[automated → EVAL {id}]` so future manual passes skip it — the highest-value mode), and coverage sweep (source-vs-tests gap map, ranked). Uses the project's existing framework only (XCTest/XCUITest on Swift incl. adding accessibility identifiers to source views, Playwright/etc. on web, pytest on Python; confirms before adding any dependency), semantic locators only, reaches state via the testability foundation's `--seed`/`--uitest` launch arguments when present (never tap-through setup; proposes adding the foundation first on Apple projects that lack it), runs every generated test to green (a red generated test is fixed or deleted, never left; a real product bug surfaced by a test is routed to `deferred`/remediation, never papered over in the test). Registers every suite as `type: command` eval cases in `docs/evals/e2e-{area}.md` (layout line added to the `evals` skill) so the backfill joins the cumulative zero-token regression net that dev-story/code-review/epic-boundary already RUN. Drops upstream's activation ceremony, TOML resolution, config.yaml/persona greeting, and the TEA-module upsell. Triggered via `/e2e-tests` ("generate e2e tests", "backfill tests", "automate the test plan").

### `doc-review`
New skill, lean port that **merges upstream's three editorial skills** (`bmad-editorial-review-structure`, `bmad-editorial-review-prose`, `bmad-review-adversarial-general`) into one three-pass skill — same merge move as `research`: they share one target (a doc reviewed as writing) and compose in a fixed order upstream itself prescribes (structure before copy-edit). Fills the gap where code gets adversarial review but the planning docs — re-read by the model in every downstream session, so bloat is a *recurring* token cost — never get reviewed as writing (`check-readiness` checks alignment, not clarity/density). Pass A structure (purpose statement → structure-model fit → CUT/MERGE/MOVE/CONDENSE/QUESTION/PRESERVE recommendations with word estimates), Pass B prose (minimal-intervention clarity fixes, three-column table), Pass C adversarial (missing sections, unsupported claims, ambiguity an implementing session would trip on, contradictions incl. against sibling planning docs). Reader-type aware: `llm` for model-consumed docs (prd/architecture/epics/CLAUDE.md — terminology consistency, no hedging, explicitness may *lengthen*), `humans` for guides (comprehension aids preserved). CONTENT IS SACROSANCT for A+B; Pass C findings are report-only and route to `/prd update`//`correct-course`, never silent meaning-edits. Apply step is user-gated (all / structure / prose / by number / none). Drops upstream's per-skill HALT ceremony, style-guide TOML plumbing, and the "clueless weasel" persona framing. Triggered via `/doc-review` ("doc review", "tighten this doc", "editorial review").

### `next`
New skill with no upstream equivalent — the **navigator**, and the fix for "which skill, in what order?". Detects project state with one **zero-token bash block** (file existence + story-frontmatter greps + inline-finding counts — never reads planning-doc *contents*), classifies it against a priority-ordered decision table spanning the whole lifecycle (uninitialized → `/setup`; brownfield-undocumented → `/discover`; idea → `/product-brief`//`prd`; planning → `/ux`//`architecture`//`epics`; gate → `/check-readiness`; dev loop → `/epic-flywheel`/resume; boundary → manual test → `/harvest-findings` → `/retrospective`; post-MVP → `/quick-dev`), and reports exactly **one** NEXT command (max two optional branches), offering to run it or recommending a fresh session when the next phase is model-heavy. Routes on two deterministic markers written for it: the `readiness-check` stamp (`check-readiness`) and per-epic `retro:` stamps (`retrospective`), both single HTML comments below the `docs/epics.md` H1. Asks at most one question per run (idea formed? ships UI? manual test done?) and records durable answers into `.leanwheel/manifest.json` `surfaces`. Runs inline — deliberately **not** a subagent (detection is one bash call; a spawn would cost more than it saves). Triggered via `/next` ("next", "what's next", "what now", "where am I", "what should I run"). Surfaced from `/setup`'s closing Next block, `/status` step 4, `/retrospective`'s Report, the README's three-command quickstart tier, and `guide/workflows.md`.

### `status`
One-line addition: step 4's next-action heuristic (which only covers the dev loop) ends by pointing at `/next` for routing beyond it (planning gaps, epic boundaries, post-MVP). Otherwise identical to upstream.

---

## Harness Assets (agentic-engineering layer)

Added to move leanwheel further from "vibe" toward "agentic engineering" (per *The New SDLC With Vibe Coding*) while staying cheap to run on the **Claude Pro plan** — every mechanism here is either zero-token (deterministic hooks, command evals, file-append observability) or token-*saving* (subagent context isolation, model routing).

### Deterministic guardrail hooks (`setup/stubs/hooks/`)
Pure bash/grep — **never call a model**, so zero token cost. Scaffolded into a project's `.claude/hooks/` by `/setup` Step 3e, wired via `hooks-settings.json`, refreshed by `/upgrade-project`:
- `guard-secrets.sh` — PreToolUse (Edit/Write/MultiEdit + Bash `git commit`). **Blocks** (exit 2) hardcoded API keys, tokens, private keys, passwords; allows env reads, keychain refs, obvious placeholders. Moves secret prevention from "the model remembers" to "the harness enforces" (the paper's canonical hook).
- `guard-design-tokens.sh` — PostToolUse. **Advisory** warning when a UI file gains a hardcoded color literal while `docs/ux/DESIGN.md` exists (mirrors swift-audit/web-audit color checks, moved to write-time). Never blocks.
- `guard-dark-pattern.sh` — PostToolUse. **Advisory** warning when a UI file gains confirmshaming (guilt-decline) copy or a pre-checked marketing/consent opt-in — the two highest-signal *textual* dark-pattern tells (semantic ones — fake progress, decoy pricing — are caught at design time in EXPERIENCE.md's Engagement & Persuasion section and in `code-review` Pass E). Excludes `.md` so planning docs discussing dark patterns don't trip it. Never blocks.
- `log-activity.sh` — PostToolUse (`*`). Appends one JSON line per tool use to `docs/metrics/activity.jsonl` (capped at 2000 lines); backs observability.

### Flywheel subagents (`agents/`)
Ship plugin-level (available wherever `leanwheel` is installed; no per-project scaffolding). `lw-story-creator` (Sonnet), `lw-story-developer` (Sonnet default; flywheel overrides to Opus on Swift), `lw-story-reviewer` (Sonnet), and `lw-docs-sync` (**Haiku**). Each runs its skill in an isolated context and returns a terse structured report — see the story-flywheel **Subagent Delegation & Model Routing** notes above. `lw-docs-sync` runs the `docs-sync` skill's OPERATIONAL/PROMOTE ops on the cheapest model so mechanical doc maintenance never lands on the dev model (Opus on Swift); the orchestrator spawns it post-dev / at the epic boundary (the dev/dev-developer subagent can't nest a child). **New agent → must be symlinked** (see Local Development reminder).

### Observability ledger (`setup/stubs/metrics/`)
Zero-token. `docs/metrics/flywheel-ledger.jsonl` gets one curated line per phase per story (model, build/test result + iterations, evals P/T, finding counts, rubric gate, invariants) appended by dev-story / code-review / story-flywheel via a single shell redirect — never read into the model. Drift indicators (rising build/test iterations, falling rubric gate, recurring `manual-required`) documented in the stub README for `/status`-style review.

---

## Web Guidance Stubs (`setup/stubs/web/`)

Mirror of the Swift stub system for web/SSG projects. Five sectioned reference files (`css-design-system.md`, `astro.md`, `hugo.md`, `accessibility-seo.md`, `anti-patterns.md`) plus the `modern-web.md` guardrails block (~50 lines, appended to project CLAUDE.md). Copied into projects by `/setup` Step 3d, routed into dev sessions by `/dev-story` step 4b, used as rejection criteria by `/code-review` and `/web-audit`, kept current by `/refresh-web`.

---

## Skills Identical to Upstream

No local changes — safe to overwrite from upstream on sync:

`architecture`, `correct-course`, `discover`, `investigate`, `prd`, `quick-dev`, `security-review`

(`setup`, `ux`, and `status` were previously in this list; all now carry local customizations documented above.)

---

## Repo Structure

```
.claude/
  skills/
    <skill-name>/
      SKILL.md        # skill prompt (uppercase — plugin convention)
agents/               # flywheel subagents (plugin-standard location, root)
  lw-story-creator.md
  lw-story-developer.md
  lw-story-reviewer.md
.claude-plugin/
  plugin.json         # plugin manifest — declares "skills": "./.claude/skills/"
  marketplace.json    # marketplace catalog — plugin source is "./"
```

## Plugin Packaging

This repo is both a plugin and its own single-plugin marketplace, installable via
`/plugin marketplace add <repo>` then `/plugin install leanwheel@leanwheel`.

- **Skills** stay in the non-standard `.claude/skills/` (preserves the personal-symlink
  + `additionalDirectories` + upstream-sync workflow). `plugin.json` exposes them with
  `"skills": "./.claude/skills/"` — a custom directory scanned *in addition to* the
  default `skills/`. Verified: all 26 load when installed.
- **Agents** must live in the plugin-standard `agents/` at the repo root. The `agents`
  manifest field pointing at files inside `.claude/agents/` validates but the agents do
  **not** register (confirmed via `claude plugin details` showing `Agents (0)`), so they
  were moved to `agents/` and the custom field dropped.
- **marketplace.json** plugin `source` is `"./"` (must start with `./`; bare `"."` fails
  schema validation). Relative sources resolve for git-based and local-dir marketplace
  adds, but NOT direct-URL-to-`marketplace.json` distribution — share via the GitHub repo.
- **No `version`** in `plugin.json` is intentional: relative-path sources in a git
  marketplace use the commit SHA, so testers get every pushed commit on
  `/plugin marketplace update`. Add+bump a `version` only if you want explicit releases.
- After any packaging change run `claude plugin validate ./` (passes with only the
  version warning).

## Local Development — symlink consumption (maintainer's machine)

The maintainer does **not** install the marketplace plugin locally — that's a frozen
snapshot for testers. Instead the skills/agents are consumed live via personal-dir
**symlinks** into this repo, so edits propagate to every project on the next session
with no commit/update/restart:

- `~/.claude/skills/<name>` → `…/leanwheel-skills/.claude/skills/<name>`
- `~/.claude/agents/<name>.md` → `…/leanwheel-skills/agents/<name>.md`

This matters because the macOS app does **not** auto-load skills from a project's
`additionalDirectories`; the personal-dir symlinks are what make them load everywhere.

> ⚠️ **REMINDER — after adding a NEW skill or agent, re-run the symlink sync.** Editing
> existing files needs nothing (symlinks are live), but a newly-*added* skill/agent has no
> symlink yet and will silently fail to load in the app (this is exactly how `swift-audit`
> went missing). Re-run:
> ```bash
> for d in /Users/rterakedis/Git-Repos/leanwheel-skills/.claude/skills/*/; do ln -sfn "$d" ~/.claude/skills/"$(basename "$d")"; done
> for a in /Users/rterakedis/Git-Repos/leanwheel-skills/agents/*.md; do ln -sfn "$a" ~/.claude/agents/"$(basename "$a")"; done
> ```
> Then restart the session. (Don't touch `~/.claude/skills/reset-git-staging-branch` — not from this repo.)
>
> **One-time post-rename cleanup (bmad-lite → leanwheel):** the local clone must be
> renamed to `…/Git-Repos/leanwheel-skills` (and `git remote set-url` after the GitHub
> repo rename), old `~/.claude/agents/bmad-*.md` symlinks removed
> (`rm ~/.claude/agents/bmad-story-*.md ~/.claude/agents/bmad-docs-sync.md`), and the
> sync re-run so the `lw-*` agents load.

## Conventions

- Skill files are always named `SKILL.md` (uppercase). Upstream uses `skill.md`.
- No `settings.json` in `.claude/` — this repo is a plugin, not a project config.
- Do not add project-level docs (`docs/`, story files, etc.) — this repo ships skills only.
- When adding a new skill or agent, also re-run the symlink sync (see **Local Development**) so it loads on the maintainer's machine.
- **Trademark rule:** "BMAD"/"BMad" appears only in *references to the upstream project* (credit, comparison, migration, upstream-sync workflow) — never in the name of anything this repo ships (skills, agents, plugin, dirs, scripts, hooks). BMad™, BMad Method™, and BMad Core™ are trademarks of BMad Code, LLC; see LICENSE third-party notices and `license-fix.md`.
