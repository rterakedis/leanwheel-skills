# CLAUDE.md — `.claude/skills/` (leanwheel skill authoring)

Loaded when working with files under `.claude/skills/`. Holds the upstream-sync workflow
and the per-skill **preserve-on-sync** table. The reasoning behind each divergence lives in
[`guide/design-decisions.md`](../../guide/design-decisions.md) (`DD-NN`) — read an entry
only when you need the why. Repo-wide rules live in the root [CLAUDE.md](../../CLAUDE.md).

## Authoring rules (this repo)

- **Contract vs conduct (DD-02).** Emphatic language (MUST / never / HALT / non-return) is
  reserved for contracts: report field names, file formats other skills parse, gate
  outcomes, immutability and irreversible-action rules. Each contract has one canonical
  home; other skills cite it ("per dev-story → Testing Plan") instead of restating it.
- **Verifiable artifacts over guardrails (DD-01).** A required output is a named report
  field plus a zero-token orchestrator check — not added prose about how to produce it.
- **No project names (DD-61).** Lessons are recorded generically in the design-decisions log.
- Skill files are `SKILL.md`; cross-references use `skills/{name}/SKILL.md`. **Budget is bytes,
  not lines** — 20 KB per SKILL.md, 4 KB per `agents/*.md` (line count turned out to be nearly
  uncorrelated with token cost; see [token-budget.md](../../guide/token-budget.md) → Per-file
  ceilings, DD-72). Enforced as a ratchet by `bash scripts/test/budget.sh`: files already over are
  grandfathered in `scripts/test/budget-baseline.txt` and **may not grow**; `--update` lowers
  ceilings as debt is paid. Over budget → move branch-conditional detail to a sibling reference
  file the skill reads only on that branch, or cut conduct prose; never pad the main file.
- Changing a report field, parsed heading, or gate outcome → update the matching case under
  `evals/` and every consumer listed in the table below. Changing `scripts/evals.sh` → run
  `bash scripts/test/evals-runner.sh`; changing `render-checklist.sh` or its template → run
  `bash scripts/test/checklist-render.sh`. `scripts/test/` holds this repo's own gates and is never
  scaffolded into projects.

## Upstream Sync Workflow

There is no maintained fork — clone upstream directly when checking for new capabilities:

```bash
git clone https://github.com/bmad-code-org/BMAD-METHOD /tmp/BMAD-METHOD
```

Upstream's files don't structurally match this repo's (different filenames, activation
ceremony, TOML customization tiers, JIT step loading), so a mechanical diff isn't useful.
Hand the comparison to an assistant with a prompt that leads with the token-minimization
philosophy so it filters for capability gains, not ceremony:

```
I maintain leanwheel-skills, a token-efficient port of the BMAD Method for Claude Code.
It deliberately strips: the per-invocation activation ceremony, three-tier TOML
customization, agent persona overhead, and JIT step-file loading — replacing them with
plain-English rules in CLAUDE.md and single-pass inline skill files. Full rationale in
guide/comparison.md and guide/features.md in this repo.

Compare /tmp/BMAD-METHOD (upstream) against .claude/skills/ in this repo. For each
upstream skill, tell me:
1. Any genuinely new capability or bugfix not present here
2. Whether porting it would require re-adding ceremony/infrastructure this repo cut
   (if so, propose a lean equivalent instead of importing it wholesale)
3. Which local skill file(s) would need to change, and a one-paragraph plan — not a
   direct file copy
Skip anything that's purely structural/ceremonial with no functional difference.
```

Treat the output as a worklist, not a patch — port the *idea* into the equivalent
`SKILL.md`, checking it against the table below first.

## Preserve on sync — per skill

| Skill | Keep (local divergence) | Why |
|---|---|---|
| `ideate` / `spec` / `elicit` / `decision-log` | Planning lives here; `product-brief` / `forge-idea` / `prd` / `ux` / `architecture` are thin aliases — never resurrect their flows. Templates, checklists, UX presets under `spec/`. | DD-50 |
| `setup` | Multi-select Apple platforms + web surface questions; copies Swift stubs (incl. `testability.md`, `simulator.md`, `core-data-cloudkit.md`, `localization.md`, `xcode-footguns.md`, `demo-data-and-copy.md`, `PROVENANCE.md`), web stubs, `simplicity.md` pointer (never inlined), hooks, `sim.sh`/`gh-track.sh`/`sabotage.sh`/`ledger.sh`/`evals.sh`, evals/metrics dirs; writes `.leanwheel/manifest.json`. Guardrails appended as a **versioned managed block**, pointer + tripwires only, never an inlined reference file. Migrate flow re-runs 3s. | DD-34 DD-40 DD-53 DD-60 DD-67 |
| `upgrade-project` | Detection-based ADD / REFRESH / CONFLICT via git provenance of the stub; never overwrites a locally-edited stub; refreshes scripts + hooks; re-syncs the versioned `<!-- leanwheel:guardrails … vN -->` block (older `vN` = REFRESH in place; no marker = CONFLICT, diffed and offered). | DD-67 |
| `check-readiness` | Checks 7–10 (cross-epic runtime deps; testing targets + Apple testability-foundation story = blocker; UX alignment; pre-mortem). Stamps `<!-- readiness-check … -->` under the epics.md H1 for `/next`. | DD-34 |
| `epics` | Cross-epic runtime dependency scan; Apple projects must carry the Epic-1 testability foundation story. | DD-34 |
| `create-story` | Cross-epic prerequisite check; Design Contract (tokens, states, identifiers, route, seed — even without `docs/ux/`); Behavior Contract + edge-case ACs + Clarification Gate; eval seeding (BUILD); **frontmatter `status:`/`title:` pinned, no body Status line**; simplicity lens; `**Shape:** migration`; epic-context cache is a reported deliverable. | DD-14 DD-23 DD-51 DD-52 |
| `dev-story` | Task/AC check-offs during work; guidance routing by topic; Design Contract as source of truth; **Build & Test Gate by running** + evals RUN/BUILD + fail-first (`sabotage.sh`); invariant evidence; design-verify for UI; **records a review base and ends at `review` with a REVIEW HANDOFF report field (pointers only) — never reviews its own diff; standalone it spawns `lw-story-reviewer` itself**; **Testing Plan report field (`AUTOMATED:` / `MANUAL:`) — canonical**; reports `INFRA TOUCHED` instead of running docs-sync under a flywheel; ledger line via `ledger.sh`. | DD-10 DD-11 DD-12 DD-31 DD-62 DD-75 |
| `code-review` | **Independence rule** (story read only up to `## Dev Agent Record` before the passes; diff = `git diff {BASE}` + untracked files; same-context review omits `--standalone`); Pass B deep security when `Security Sensitivity` is set; Pass D includes UNVERIFIED invariants; Clean-review line; epic-context learnings (never stubs a missing cache); Pass E design/dark-pattern + identifier checks; Pass F over-engineering; component inventory; **Verify green** (build+test+evals) after patches + **verify-green gate rule (blocked = red, no qualified PASS) — canonical**; SCORE rubric; DRIFT flag; **`[Fix-Now]` ceiling — canonical**; ledger line via `ledger.sh`. | DD-11 DD-12 DD-23 DD-56 DD-62 DD-75 |
| `deferred` | `d_id` required in LOG-AND-SCHEDULE; rejects Fix-Now-grade items. | DD-12 |
| `evals` | `type: command` default, `judge` opt-in; **RUN is `scripts/evals.sh`, never an in-context parse of `docs/evals/*.md`** — the script owns batching by identical `run:`, empty-stdout failure, no-`run:`/unparseable-`expect:` as failures, README exclusion, and the report line; enumerating gates assert a lower bound. | DD-11 DD-13 DD-71 |
| `design-verify` | Seed-arg launches via `sim.sh` to render contract states; writes `### Design Verification`. | DD-40 |
| `story-flywheel` | Epic number from milestone *title*; `gh api --jq` filtering; **Subagent delegation + model/effort routing table — canonical** (all three pinned Sonnet; dev-story gets a `model: opus` override on Swift only — Opus is the flywheel's cost ceiling, a Fable session is never inherited; Haiku docs-sync; effort pinned per runner, never inherited; no mid-session model or effort switching — both bust the prompt cache); **reviewer spawned on every story with the REVIEW HANDOFF verbatim — no blast-radius gating, no summary; fallback records `review=inline-fallback`**; **non-return + PID/artifact wait rule — canonical**; Phase 4 checkpoint with VERIFICATION + TESTING PLAN shape; ledger roll-up via `ledger.sh` every story; auto-pilot option; inline-on-session-model fallback. | DD-20 DD-21 DD-62 DD-73 DD-75 |
| `epic-flywheel` | Commit-per-step with authorization; orchestrator-owned `gh-track.sh` transitions; epic-context file gate after create; auto-advance on green; Boundary Gate (whole-project build+test, cumulative evals, invariant + deferred sweeps, CLAUDE.md budget, tracking reconcile, PROMOTE) — HALT on any failure; **rolled-up / deduped / subtracted test plan** with `Automated — do not re-test:` per flow and full-flag setup commands; physical-device backlog; conditional squash-merge; mandatory retro reminder. | DD-22 DD-23 DD-25 DD-30 DD-31 DD-58 |
| `harvest-findings` | Deterministic finding parse (indented non-checkbox bullet); capture to `docs/epics.md` before authoring (foldable block shape); kind × disposition routing incl. `plan-defect`; **done stories immutable**; fold remediation ACs back into the plan. | DD-32 DD-33 |
| `retrospective` | Seven questions (human-in-the-loop, never auto-generated); harvest first; two-pass deferred audit incl. `leanwheel:` markers; PROMOTE; CONDENSE; CLAUDE.md tier audit; retro stamp; half-rule lens; per-epic ledger metrics by model. | DD-20 DD-54 DD-55 DD-58 |
| `epic-archive` | CONDENSE keyed off the retro stamp; CUT-RELEASE with continuous numbering, ledger rotation, deferred re-homing; story files never moved. | DD-55 |
| `e2e-tests` | Existing framework only; flows per `simulator.md`; registers command evals; converted test-plan steps are removed and named on `Automated — do not re-test:`. | DD-35 DD-36 |
| `docs-sync` | OPERATIONAL / PROMOTE / DRIFT; three audiences; never writes `docs/setup/swift|web`; runs as `lw-docs-sync` (Haiku). | DD-24 |
| `github-tracking` | SYNC op; mechanics in `scripts/gh-track.sh`, policy in the skill. | DD-22 |
| `quick-dev` | Phase 4 operational-guides step via `lw-docs-sync`. | DD-24 |
| `dev-single-goal` | Doc-free lane; self-ignoring `.leanwheel/goals/`; redirect to `/quick-dev` when docs exist. | DD-57 |
| `architecture` (alias) / `ux` | Dependency-justification beat (architecture); SSG preset, delta-only tokens, mock-coverage confirmation, Engagement & Persuasion section (ux → `spec`). | DD-53 DD-56 |
| `product-brief` / `forge-idea` / `research` / `doc-review` | Merged lean ports (brainstorm+brief; forge exit states; three research types in one; three editorial passes in one). | DD-50 |
| `refresh-swift` / `refresh-web` | Gold-standard + curated-author sources, idea-port only, version-axis rules; refresh-swift also refreshes `appstore-preflight` / `appstore-connect` facts. **`<!-- FIELD -->` blocks are protected** — append/version-scope/retire-with-citation only, never a silent rewrite; conflicts are reported, not decided. Must bump the guardrails block `vN` on any change to it. | DD-66 DD-67 |
| `swift-audit` / `web-audit` | Remediation story output; Pass-F deletion tags; swift-audit Step 4b testability retrofit staged Stage 0..N. | DD-34 DD-35 |
| `appstore-preflight` / `appstore-connect` | Dated fact tables with Currency note (refreshed by `/refresh-swift`); `docs/store/` artifacts in fastlane layout; user-supplied bezels; bash `asc-lint.sh` (canonical copy beside SKILL.md, byte-identical copy in `setup/stubs/hooks/`). Design log: `guide/appstore-connect.md`. `compose.swift` prunes its own stale output (validated-first, own-pattern-only, never under `--dry-run`/`--only`); `asc-lint.sh` WARNs on plan-orphaned screenshots. Optional `docs/store/template.json` styling merged **per key** over the plain default — absent/empty ⇒ byte-identical output, defaults are the original expressions (`0.94`, not `1 - 0.06`), nil-defaults where no number expresses the old behaviour, malformed ⇒ named error writing nothing, and no rendering change is ever gated on template *presence*. Captions are `id: Caption [| Subtitle]`. Preflight Step 7b authors the Guideline 2.1 review packet from `appstore-preflight/review-packet.md` (a `<!-- FIELD -->` file); its gate is `asc-lint.sh` (`notes.txt` ≤ 4000, WARN per `UNVERIFIED` row in `review-claims.md`). **Progressive disclosure:** connect's ops live in `op-{assets,metadata,products}.md`, each read only by its op; preflight's CloudKit/StoreKit branches live in `checks-{cloudkit,storekit}.md`, read only when Step 1 finds them; the checklist is rendered by `render-checklist.sh` from `submission-checklist.template.md`, never read (markers `{omit if no StoreKit|CloudKit}`, `{+ … if universal}`; test: `scripts/test/checklist-render.sh`). Never merge these back into SKILL.md. | DD-43 DD-65 DD-68 DD-70 DD-74 |
| `next` / `status` | Zero-token state detection routed on the readiness / retro stamps; `status` points at `/next`. | — |
| `correct-course`, `discover`, `investigate`, `prd` (alias), `security-review` | Identical to upstream — safe to overwrite on sync. | — |

## Cross-cutting assets

- **Simulator automation** (`scripts/sim.sh`, `stubs/swift/simulator.md`, `stubs/swift/testability.md`, `guard-a11y-id.sh`): route-based navigation, `--route`/`--seed` contract, orientation, store preset, `.leanwheel/sim.json` committed, REGRESSION GUARD comments at the two silent-failure sites. DD-40 – DD-44.
- **Provenance** (`stubs/swift/PROVENANCE.md`, `<!-- FIELD -->` markers): research knowledge ages on the OS cadence and is refreshed; field knowledge is trial-and-error, absent from primary sources, and retires only when a citation shows the *mechanism* changed. `grep -rn "<!-- FIELD" stubs/swift/` before any refresh pass. DD-66.
- **Hooks** (`setup/stubs/hooks/`): `guard-secrets.sh` blocks (exit 2); `guard-design-tokens.sh`, `guard-dark-pattern.sh`, `guard-a11y-id.sh`, `guard-context-budget.sh`, `asc-lint.sh` advisory; `log-activity.sh` capped at 2000 lines. DD-60.
- **Scripts**: `gh-track.sh` (tracking), `sabotage.sh` (prove a gate can fail), `evals.sh` (schema owner for the `docs/evals/` case format — collects, batches, asserts, reports; the only sanctioned way to RUN the net, and the CI seam), `ledger.sh` (normalized ledger appends + verify-green enforcement), `sim.sh`, `commit-push.sh`. Executed, never read into context. Build/test gates run quiet and `tee` full logs to the self-ignoring `.leanwheel/logs/` (DD-63).
- **Agents** (`agents/`): two axes, both pinned in frontmatter — model and **effort**. `lw-story-creator` (Sonnet, `medium`), `lw-story-developer` (Sonnet, `high`; Opus on Swift by per-spawn override — never Fable), `lw-story-reviewer` (Sonnet, `high`; spawned after every dev pass, prompt = the REVIEW HANDOFF), `lw-docs-sync` (Haiku, `low` — inert on Haiku, kept for a future re-tier). Effort is pinned on every runner rather than inherited: a spawn is its own conversation, so pinning costs no cache, while inheriting would let a `max`-effort session leak past the model cost ceiling. Each carries a one-line non-return reinforcement beside its report contract. **New agent or skill → re-run the symlink sync** (root CLAUDE.md).
- **Ledger** (`stubs/metrics/`): `docs/metrics/flywheel-ledger.jsonl`, one line per phase per story, appended only via `scripts/ledger.sh` (schema owner; refuses qualified PASS), rotated by CUT-RELEASE. DD-62.
- **Web stubs** (`setup/stubs/web/`): mirror of the Swift stub system; routed by dev-story, used by code-review / web-audit, refreshed by `/refresh-web`.
