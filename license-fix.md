# License & Trademark Remediation Plan

**Status:** Phase 1 applied on branch `claude/bmad-license-compliance-ayjbem` · Phase 2 pending a naming decision
**Prepared:** 2026-07-04

---

## TL;DR

The concern raised is real, but it is **two separate legal issues**, and only one of them is
actually about the MIT license:

1. **MIT license compliance (copyright).** The MIT license does **not** restrict names at all.
   What it *does* require is that upstream's copyright + permission notice be retained in all
   copies or substantial portions of the Software. This repo is a derivative work of
   [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) (several skills are documented in
   CLAUDE.md as "identical to upstream"), but `LICENSE` carried only this repo's own copyright
   line. **That was a genuine MIT violation. Fixed in Phase 1** by appending upstream's full
   notice to `LICENSE`.

2. **Trademark (the naming problem).** Upstream's `LICENSE` ends with a trademark notice, and
   their [`TRADEMARK.md`](https://github.com/bmad-code-org/BMAD-METHOD/blob/main/TRADEMARK.md)
   states that **BMad™, BMad Method™, and BMad Core™ — in all casings and variations (BMAD,
   bmad, BMAD-METHOD, etc.) — are trademarks of BMad Code, LLC and are *not* licensed under the
   MIT License.** Their policy explicitly permits forking and redistributing the software, but
   **only "under a different name"**, and explicitly prohibits using "BMad" or any confusingly
   similar variation **as your product name**. Their own examples list "BMadFlow" and "BMad Pro" as
   not permitted — `bmad-lite` is squarely in that category. **This requires renaming the
   product (Phase 2).**

Referential uses — "derived from / inspired by / a port of the BMAD Method", "compatible with
BMAD Method", migration instructions for full-BMAD projects — are **explicitly permitted**
(nominative fair use; their Permitted column includes "An alternative implementation inspired by
BMad"). Those stay.

---

## What upstream's terms actually say

From `BMAD-METHOD/LICENSE` (MIT, Copyright (c) 2025 BMad Code, LLC):

> TRADEMARK NOTICE:
> BMad™, BMad Method™, and BMad Core™ are trademarks of BMad Code, LLC, covering all
> casings and variations (including BMAD, bmad, BMadMethod, BMAD-METHOD, etc.). The use of
> these trademarks in this software does not grant any rights to use the trademarks
> for any other purpose. See TRADEMARK.md for detailed guidelines.

From `BMAD-METHOD/TRADEMARK.md` — **you may**:

- Use the software under the MIT License
- Refer to BMad to accurately describe compatibility or integration
- **Fork the software and distribute your own version under a different name**

**You may not**:

- Use "BMad" or any confusingly similar variation **as your product name, service name,
  company name, or domain name**
- Present your product as endorsed by BMad Code, LLC
- Register domain names or social-media handles incorporating BMad branding

---

## Findings

| # | Issue | Legal basis | Severity | Status |
|---|-------|-------------|----------|--------|
| F1 | `LICENSE` omitted upstream's copyright + permission notice despite the repo containing skills ported from (and several "identical to") upstream | MIT License condition ("The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software") | **Violation — must fix** | ✅ Fixed in Phase 1 |
| F2 | "bmad" used as **product identity**: repo name `bmad-lite-skills`, plugin/marketplace name `bmad-lite`, agent names `bmad-*`, scaffolded manifest dir `.bmad-lite/`, "BMAD-LITE" branding throughout docs, hooks, and scripts | Trademark policy (outside the MIT grant) — prohibits BMad-derived product names | **Violation — must fix** | ⏳ Phase 2 (needs a name decision) |
| F3 | Referential mentions: "port of the BMAD Method", credit section, migration guide for full-BMAD projects, `_bmad/` detection in `/setup migrate` | Nominative fair use — explicitly permitted by TRADEMARK.md | **Compliant — keep** | No action |

Note on F1: CLAUDE.md's sync policy is "port ideas, never direct file copies," and ideas aren't
copyrightable — but CLAUDE.md also lists eight skills as "identical to upstream," and many
others are described as "lean ports." Including the upstream notice is cheap, removes all doubt,
and is required for any content that qualifies as a substantial portion. It stays regardless of
the rename.

---

## Phase 1 — MIT compliance + attribution hygiene (applied on this branch)

1. **`LICENSE`** — kept this repo's own MIT license, appended a **Third-Party Notices** section
   reproducing upstream's full MIT notice verbatim (copyright line, permission notice, warranty
   disclaimer) plus their trademark notice, with a one-line statement of what is derived.
2. **`README.md` Credit section** — already present and largely correct; updated the trademark
   line to cover all three claimed marks (BMad™, BMad Method™, BMad Core™) and to link
   upstream's `TRADEMARK.md`.

Nothing else in Phase 1 — partial renames before a name is chosen would just churn the diff.

---

## Phase 2 — Rename the product (requires one decision: the new name)

The MIT license permits keeping everything; the trademark policy requires the *product* stop
being called anything BMad-derived. One decision is needed — the new name — then the rename is
mechanical.

### Name candidates

Check GitHub/npm/plugin-marketplace collisions before committing. The tagline
"a lean, token-efficient port of the BMAD Method™" remains permitted alongside any of these.

| Candidate | Rationale |
|---|---|
| **`flywheel-lite`** (recommended) | "Planning flywheel" is already the repo's core motif and appears throughout the docs; "lite" carries over the positioning. |
| `storyforge` | Story-centric loop; distinctive. |
| `leanflow-skills` | Descriptive of the token-lean workflow. |
| `agileloop` | Describes the create→dev→review loop. |

> ⚠️ Avoid anything containing `bmad`, `bmd`, or soundalikes ("beemad", "b-mad") — "confusingly
> similar variation" is explicitly covered by their policy.

`{NEW-NAME}` below stands for the chosen name.

### 2a. Rename inventory — product-identity uses (must change)

| Surface | Current | Change to | Notes |
|---|---|---|---|
| GitHub repo | `rterakedis/bmad-lite-skills` | `rterakedis/{NEW-NAME}` | Owner-only action (repo Settings → Rename). GitHub auto-redirects old clone URLs and web links. Do this **last**, after the content rename lands on `main`. |
| Plugin manifest | `.claude-plugin/plugin.json` `"name": "bmad-lite"`, "BMAD-LITE …" description | `"{NEW-NAME}"` + reworded description | Installed testers must uninstall `bmad-lite@bmad-lite` and reinstall — a plugin rename is a new plugin. Announce it. |
| Marketplace manifest | `.claude-plugin/marketplace.json` (marketplace name + plugin entry, 4 hits) | `{NEW-NAME}` | Same reinstall caveat. |
| Agents | `agents/bmad-story-creator.md`, `bmad-story-developer.md`, `bmad-story-reviewer.md`, `bmad-docs-sync.md` — filenames, `name:` frontmatter, body text | `{NEW-NAME}-story-creator` etc. (or drop the prefix: `story-creator`, `story-developer`, `story-reviewer`, `docs-sync-agent`) | Every reference in `story-flywheel`, `epic-flywheel`, `docs-sync`, `dev-story`, `quick-dev`, CLAUDE.md must be updated in the same commit. Maintainer must re-run the symlink sync **and delete the stale `~/.claude/agents/bmad-*.md` symlinks**. |
| Scaffolded manifest dir | `.bmad-lite/manifest.json` (written by `/setup` Step 5, read by `/upgrade-project`) | `.{NEW-NAME}/manifest.json` | **Back-compat required:** `/upgrade-project` detection must read the old `.bmad-lite/manifest.json` if present and migrate it to the new path, so existing scaffolded projects upgrade cleanly. |
| Scaffolded scripts & hooks | `scripts/gh-track.sh` (header comment + close-comment text "closed by bmad-lite"), `stubs/hooks/guard-secrets.sh`, `guard-design-tokens.sh`, `log-activity.sh` (header comments + user-facing messages "BLOCKED by bmad-lite guard-secrets") | `{NEW-NAME}` | These live inside **user projects** after scaffolding; `/upgrade-project`'s stub-refresh path picks up the new versions. |
| Skill text | `setup/SKILL.md` (~26 product-identity hits), `upgrade-project/SKILL.md` (incl. the "sync bmad" trigger phrase → "sync skills"), `story-flywheel`, `epic-flywheel`, `docs-sync`, `retrospective`, `quick-dev`, `harvest-findings`, `dev-story` | `{NEW-NAME}` / "this framework" | See the caution in 2c — `setup`'s migrate flow also contains *referential* BMAD mentions that must NOT change. |
| Docs & meta | `README.md` (title + body), `CLAUDE.md` (~27 hits), `guide/*.md` (comparison, features, migration, token-budget, skills-reference, installation, github-tracking, project-layout, deferred-items, workflows), `CONTRIBUTING.md`, `SECURITY.md`, `.github/` issue/PR templates | `{NEW-NAME}` for product identity; keep upstream references | The README title, install commands (`/plugin install bmad-lite@bmad-lite`), and "BMAD-LITE" branding all change. |
| Maintainer machine | `~/.claude/skills/*` and `~/.claude/agents/bmad-*.md` symlinks; local clone path `/Users/rterakedis/Git-Repos/bmad-lite-skills` | re-link; optionally re-clone/`git remote set-url` after the repo rename | The symlink-sync loop in CLAUDE.md's Local Development section references the old path — update it too. |

### 2b. What stays (permitted referential use)

- README Credit section: "derived from and inspired by **BMAD Method** by BMad Code, LLC, used
  under the MIT License" + trademark disclaimer — this is the model TRADEMARK.md endorses.
- `LICENSE` Third-Party Notices (Phase 1) — required, not optional.
- CLAUDE.md's **Upstream Sync Workflow** section (cloning `BMAD-METHOD`, comparison prompt) —
  references the upstream project by its actual name; keep.
- `guide/comparison.md` / `guide/features.md` "vs original BMAD" analyses — comparative,
  referential; keep (retitle only where they call *this* project "BMAD-LITE").
- `guide/migration.md` and `/setup migrate|clean`: detection of `_bmad/`, `src/bmm-skills/`,
  `sprint-status.yaml` from **upstream** installs, and prose like "Found full BMAD
  infrastructure" — these name the upstream product to describe interoperability; keep.
- The phrase "compatible with BMAD Method" or "a lean port of the BMAD Method™" in the new
  README tagline — explicitly permitted.

### 2c. Execution notes

- **Do not run a blind `sed s/bmad/{NEW-NAME}/gi`.** It would corrupt the permitted referential
  uses (F3) and break `/setup migrate`'s detection of upstream's `_bmad/` directories. Do a
  guided pass per file class: rename product-identity strings (`bmad-lite`, `BMAD-LITE`,
  `bmad-lite-skills`, `.bmad-lite/`, `bmad-story-*`, `bmad-docs-sync`), leave upstream
  references (`BMAD Method`, `BMAD-METHOD`, `full-BMAD`, `_bmad/`, `bmad-code-org`) intact.
  A safe starting filter: `grep -rn 'bmad-lite\|BMAD-LITE\|bmad-story\|bmad-docs-sync\|\.bmad-lite'`
  matches product identity almost exclusively.
- Land everything except the GitHub repo rename in **one commit** (manifests + agents + skills +
  docs together), so the plugin never ships half-renamed.
- Sequence: choose name → content rename commit → validate (`claude plugin validate ./`) →
  merge → rename GitHub repo → update maintainer symlinks/remote → announce reinstall to
  testers → `/upgrade-project` in scaffolded projects refreshes their local scripts/hooks and
  migrates `.bmad-lite/` → new manifest dir.

---

## Phase 3 — External surfaces & ongoing hygiene

1. **Domains / social handles:** none known for this project; if any exist containing "bmad",
   retire them (explicitly prohibited by TRADEMARK.md).
2. **Marketplace/directory listings** referencing `bmad-lite`: update after the rename.
3. **Ongoing rule** (add to CLAUDE.md conventions after Phase 2): "BMAD"/"BMad" appears only in
   *references to the upstream project* (credit, comparison, migration, sync workflow) — never
   in the name of anything this repo ships (skills, agents, plugin, dirs, scripts, hooks).
4. **Optional goodwill:** email contact@bmadcode.com noting the rename and attribution — not
   legally required, but their TRADEMARK.md invites contact and it removes any residual risk of
   a complaint.

---

## Why the rename is genuinely required (anticipating pushback)

- "But MIT is permissive" — MIT covers the **code**, and upstream says so explicitly: "The MIT
  License applies to the software code only, not to the BMad brand identity." Trademark rights
  exist independently of the copyright license.
- "But we credit them" — attribution doesn't cure trademark use as a product name; if anything,
  a prominent "not affiliated" disclaimer coexisting with a BMad-derived *name* highlights the
  likelihood-of-confusion problem.
- "But it's non-commercial/free" — trademark policies apply to free products too; their policy
  makes no commercial/non-commercial distinction for the naming rule.
- "Is `bmad-lite` really 'confusingly similar'?" — it *contains the mark verbatim* plus a
  descriptor, the exact pattern their examples prohibit ("BMad Pro", "BMadFlow"). This is not a
  close call.
