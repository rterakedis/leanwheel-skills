---
name: next
description: Detect where the project is in the leanwheel lifecycle and recommend the single next command — the answer to "what do I run now?" at any point from empty folder to post-MVP. Use when the user says "next", "what's next", "what now", "what should I run", "where am I", or opens a session unsure how to continue.
---

# Next (Navigator) Skill

**Goal:** Kill "which skill, in what order?" — route to exactly one next command from deterministic project state.

**Token posture:** near-zero. Existence checks + frontmatter greps only. **Never read planning-doc contents** — the whole point is routing without loading `prd.md`/`architecture.md` into this session.

## Step 1 — Detect (one bash block, zero model reads)

```bash
setopt null_glob 2>/dev/null || shopt -s nullglob 2>/dev/null || true
echo "== scaffold =="
for f in CLAUDE.md AGENTS.md .leanwheel/manifest.json; do [ -e "$f" ] && echo "HAVE $f"; done
[ -f .leanwheel/manifest.json ] && grep -o '"surfaces":[^}]*}' .leanwheel/manifest.json
echo "== planning docs =="
for f in docs/project/brief.md docs/prd.md docs/ux/DESIGN.md docs/ux/EXPERIENCE.md docs/architecture.md docs/epics.md docs/deferred-items.md docs/project/forged-idea-*.md; do [ -e "$f" ] && echo "HAVE $f"; done
echo "== gates =="
grep -m1 'readiness-check' docs/epics.md 2>/dev/null || echo "no readiness stamp"
grep -o 'retro: epic [0-9]*' docs/epics.md 2>/dev/null || echo "no retro stamps"
echo "== stories =="
grep -H -m1 '^status:' docs/epics/*.md /dev/null 2>/dev/null
grep -H -m1 '^\*\*Status:\*\*' docs/epics/*.md /dev/null 2>/dev/null   # legacy format
echo "== test plans =="
for p in docs/epics/epic-*-test-plan.md; do [ -e "$p" ] && echo "$p inline-findings:$(grep -cE '^[[:space:]]+[-*] ' "$p")"; done
echo "== source tree =="
for d in *.xcodeproj *.xcworkspace Package.swift package.json pyproject.toml go.mod src Sources app; do [ -e "$d" ] && echo "$d"; done
echo "== guidance age =="
find docs/setup/swift docs/setup/web -name '*.md' -mtime +90 2>/dev/null | head -1
echo "== done =="
```

(The `null_glob`/`nullglob` line makes unmatched globs expand to nothing in both zsh and bash; the `/dev/null` arg keeps `grep` from reading stdin when no story files exist.)

## Step 2 — Classify (first matching row wins)

| # | Condition | Phase | NEXT |
|---|---|---|---|
| 1 | No CLAUDE.md/AGENTS.md scaffold | Not initialized | `/setup` (then `/github-tracking setup`) |
| 2 | Scaffold + source tree present, no `docs/prd.md` | Brownfield, undocumented | `/discover` |
| 3 | No prd, no brief | Idea | Ask once: idea formed? Yes → `/prd` · fuzzy → `/product-brief` |
| 4 | Brief, no prd | Idea → Plan | `/prd` — optional first: `/forge-idea` if no `forged-idea-*.md` (pressure-test) |
| 5 | Prd; manifest surfaces show UI (apple/web app/SSG); no `docs/ux/DESIGN.md` | Plan | `/ux` (no manifest → ask once: does this ship UI?) |
| 6 | No `docs/architecture.md` | Plan | `/architecture` |
| 7 | No `docs/epics.md` | Plan | `/epics` |
| 8 | Epics, no readiness stamp | Gate | `/check-readiness` — optional first: `/doc-review` on prd/architecture |
| 9 | Any story `status: review` | Dev loop | `/code-review` on that story |
| 10 | Any story `status: in-progress` | Dev loop | `/dev-story` to resume it (or resume `/epic-flywheel {N}` if the epic was mid-flywheel) |
| 11 | Current epic has unbuilt stories (`ready-for-dev` in files, or in `docs/epics.md` with no story file) | Dev loop | `/epic-flywheel {N}` (default) · hands-on alternative: `/story-flywheel` or `/create-story` |
| 12 | Epic's stories all done; `epic-{N}-test-plan.md` has inline findings > 0 | Boundary | `/harvest-findings {N}` |
| 13 | Test plan exists, findings = 0, no retro stamp for {N} | Boundary | Ask once: manual test pass done? No → run the test plan (optional: `/e2e-tests` to automate it) · Yes → `/retrospective` |
| 14 | Retro stamped for {N}, later epics remain | Next epic | `/epic-flywheel {N+1}` — in a **fresh session** |
| 15 | All epics done | Post-MVP | `/quick-dev` for one-offs · bigger feature area → `/prd update` then `/epics` · new product idea → `/product-brief` |

To resolve rows 11–14, `docs/epics.md`'s story table may be skimmed for epic/story numbering only — never the prose.

**Tickler (append max one line, only on signal):** guidance-age hit → suggest `/refresh-swift` / `/refresh-web`.

## Step 3 — Report

```
LEANWHEEL NAVIGATOR
Phase: {name}
Done:  {compact artifact checklist, e.g. brief ✓ prd ✓ ux ✓ arch — epics —}
NEXT → {one command}
Why:   {one sentence}
Optional: {0–2 branches, one line each}
```

Then offer: run `{command}` now, or start a fresh session and run it there. Recommend the fresh session whenever the next phase is model-heavy (prd, architecture, epics, any flywheel) and this session already carries significant context — phase isolation is the core token discipline.

## Step 4 — Act

- User says run → invoke the recommended skill directly (normal skill invocation; it takes over).
- User picks an optional branch → invoke that instead.
- Otherwise stop — the report is the deliverable.

## Rules

- Exactly **one** NEXT. Max two optionals. Never dump the full lifecycle map.
- Ask at most **one** question per run, only when a row genuinely can't be resolved from detection (idea formed? ships UI? manual test done?). If the answer is durable (UI surfaces), record it into `.leanwheel/manifest.json` `surfaces` when the file exists.
- Never re-run a completed phase; never route destructively. This skill only detects and routes.
- Inconsistent state (e.g., story files but no `docs/epics.md`) → say what's inconsistent and route to the repair (`/setup` idempotent re-run, or name the missing artifact) instead of guessing forward.
