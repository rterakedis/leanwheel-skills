---
name: appstore-preflight
description: Audit an iOS/iPadOS SwiftUI project's configuration, privacy declarations, and review-sensitive behaviors against App Store / TestFlight submission requirements. Produces a remediation story plus a non-code submission checklist. Use when the user says "app store preflight", "appstore preflight", "app store readiness", "ready to submit", "testflight readiness", or "publish the app".
---

# App Store Preflight Skill

**Goal:** Scan the Xcode project — Info.plist / build settings, entitlements, privacy manifests, assets, dependencies, and source — for the configuration gaps and guideline footguns that cause upload failures (ITMS errors), TestFlight blocks, and App Store review rejections. Collate findings into a `/dev-story`-ready remediation story, and generate the **non-code submission checklist** (App Store Connect metadata, legal/business items) the developer must complete by hand.

**Requires:** An Apple app project (`.xcodeproj`, `.xcworkspace`, or an app-target `Package.swift`). If absent, the scan exits 2 with "No Apple app project found — nothing to preflight." — stop there.

**Currency note:** Requirement facts are dated by the `currency` row of `preflight-facts.tsv` (printed as `INVENTORY|facts`); that date covers every file of this skill. Items marked ⚠️VOLATILE change frequently (litigation, annual SDK mandates) — re-verify against https://developer.apple.com/news/upcoming-requirements/ at submission time rather than trusting these files.

---

## Step 1 — Scan (zero-token)

```bash
bash {skills_path}/.claude/skills/appstore-preflight/preflight-scan.sh .
```

**Execute it; never read it or `preflight-facts.tsv`** (owned by `/refresh-swift`, pinned by `scripts/test/preflight-scan.sh`). Plist checks cover Info.plist files and `INFOPLIST_KEY_*` build settings; test targets, `Pods/`, `.build/` and `#if DEBUG` code are excluded.

**Output contract (canonical here; the script header mirrors it).** One record per line; the last field is free text:

| Line | Meaning |
|---|---|
| `INVENTORY\|<topic>\|<value>` | what exists (targets, plists, manifests, entitlements, deps, keys, versions, toolchain) |
| `FINDING\|<SEV>\|<SCOPE>\|<rule-id>\|<file[:line]>\|<message>` | a mechanical verdict, BLOCKER first. SEV and SCOPE are Step 6's |
| `JUDGE\|<topic>\|<file[:line]>\|<excerpt>` | found mechanically; you decide. Each topic opens with one line at location `-` carrying the question and its severity/guideline |
| `VERIFY-BY-HAND\|<id>\|<text>` | not visible in the repo → a Step 7 checklist item, never a story AC |
| `FLAGS\|<key>=yes\|no…` | keys `cloudkit storekit universal permission-requests account-creation third-party-login att ai-endpoint webview-primary ugc remote-config`; routes Step 5 and Step 7 |
| `SCAN: <n> findings — B/H/M/L; <j> judge, <v> verify-by-hand; flags <yes-list>` | last line |

Exit 0 = complete (findings are data); 1 = facts file malformed or out of step with the script — report the stderr line and stop, never fall back to hand-grepping; 2 = usage or no project.

**FINDING lines are verdicts:** carry each into Step 6 as-is. A false positive (e.g. a pattern hit in a string literal) stays out of the story and is named, with the reason, in the Step 8 report. `docs/ux/`, `docs/prd.md` (feature intel for Step 5), and `.leanwheel/manifest.json` are read only if present.

---

## Steps 2–4 — Judgment on the residue (purpose strings, manifest, configuration)

Answer each `JUDGE` topic's question for each of its hits: a real problem becomes a finding with the question's guideline/ITMS code and scope, severity per Step 6; anything else is dropped. Then the two checks the scan has no trigger for:

- **SDK-linked APIs.** SDKs that link protected APIs trip the upload scanner even if the app never calls them (Stripe card-scan, Twilio, Firebase ML). Check `INVENTORY|dependencies` against `INVENTORY|purpose-keys`; a missing key → **BLOCKER** `[PLIST]` (ITMS-90683).
- **CloudKit** (`cloudkit=yes`) → apply [checks-cloudkit.md](checks-cloudkit.md); the scan has already emitted its mechanical half (`cloudkit-schema-init`, `VERIFY-BY-HAND|cloudkit-deploy`).

---

## Step 5 — Review-Behavior Audit (guideline semantics)

These need judgment, not just grep. Read the relevant source (auth flows, paywall, settings) selectively — do not read the whole codebase. Read a branch file only when its `FLAGS` trigger is `yes` (item 4: `storekit`, item 11: `permission-requests`); items 6 and 7 always run.

| Items | Trigger | Read |
|---|---|---|
| 1–2 account deletion 5.1.1(v), login services 4.8 | `account-creation` or `third-party-login` | [checks-accounts.md](checks-accounts.md) |
| 3, 5 ATT 5.1.2, third-party AI 5.1.2(i) | `att` or `ai-endpoint` | [checks-data-sharing.md](checks-data-sharing.md) |
| 8–10 hidden features 2.3.1, web wrapper 4.2, kids/age 1.2 | `remote-config`, `webview-primary`, `ugc`, or a Kids Category PRD | [checks-content.md](checks-content.md) |

4. **Subscriptions/IAP — 3.1.1/3.1.2.** StoreKit in use (Step 1) → apply [checks-storekit.md](checks-storekit.md): PRODUCTS DIFF reconciliation **and** the 3.1.2(c) paywall hierarchy check (billed amount dominates). No StoreKit → skip.
6. **In-app privacy policy access — 5.1.1.** A privacy-policy link must be reachable inside the app (settings screen is fine). Missing → **MEDIUM**.
7. **iPad compatibility — 2.4.1.** Every app is reviewed on iPad, **even iPhone-only apps** (compatibility mode). Note as a checklist test item; flag obvious fixed-width/fixed-orientation layouts in a universal app → **MEDIUM**.
11. **Permission pre-prompts — 5.1.1(iv).** Any `request*Authorization` / `requestAccess` call site (grep in [checks-permissions.md](checks-permissions.md)) → apply that file: neutral button copy, no exit around the system alert, user-action trigger. Pre-prompts are invisible to automation, so an unwalked one is a MEDIUM finding.

---

## Step 6 — Triage & Remediation Story

Severity:
- **BLOCKER** — machine-enforced: upload fails (ITMS-*) or TestFlight build unusable
- **HIGH** — near-certain review rejection
- **MEDIUM** — likely reviewer friction or policy drift
- **LOW** — best practice

Scope tags: `[PLIST]` `[MANIFEST]` `[SIGNING]` `[ASSET]` `[CODE]` `[BEHAVIOR]`. Deduplicate per file. Items that are verify-by-hand (provisioning profile contents, App ID capabilities) become checklist items in Step 7, not story ACs.

If zero code/config findings: report "Preflight clean — configuration ready for submission." and continue to Step 7 (the checklist always ships).

Otherwise write `docs/maintainer/appstore-preflight-{YYYY-MM-DD}.md`, mirroring the swift-audit format:

```markdown
---
Status: ready-for-dev
Type: remediation
Generated: {date}
---

# App Store Preflight Remediation — {date}

**Source:** `/appstore-preflight`
**Findings:** {N} total — {B} BLOCKER / {H} HIGH / {M} MEDIUM / {L} LOW

## Acceptance Criteria
<!-- BLOCKER first, then HIGH/MEDIUM/LOW; grouped by scope tag -->
- [ ] [BLOCKER][PLIST] {description} — `{file or build setting}`
- [ ] [HIGH][BEHAVIOR] {description} — `{File.swift}:{line}`

## Tasks
- [ ] Resolve all BLOCKER findings (each prevents upload or TestFlight distribution)
- [ ] Resolve HIGH findings (each is a likely rejection)
- [ ] Re-run `/appstore-preflight` after fixes to confirm clean

## Dev Notes
### Finding Details
{Per finding: what was found (snippet/key), why it fails (ITMS code or guideline number), the exact fix}
```

---

## Step 7 — Submission Checklist (non-code)

Write `docs/maintainer/appstore-submission-checklist.md` (overwrite on re-runs — it's a living gate, not a log) in two moves:

1. **Render (zero-token)** from [submission-checklist.template.md](submission-checklist.template.md) using the Step 1 `FLAGS` values for `storekit`, `cloudkit`, and `universal`. Run the script; don't read the template:
   ```bash
   bash {skills_path}/.claude/skills/appstore-preflight/render-checklist.sh \
     --storekit yes|no --cloudkit yes|no --universal yes|no --date {YYYY-MM-DD} \
     --out docs/maintainer/appstore-submission-checklist.md
   ```
   It drops the sections and lines that don't apply, notes each omission at the top, and reports how many `{…}` placeholders remain.
2. **Fill** — read the rendered file and replace every remaining placeholder. Pre-fill every item the audit can infer as `[x] verified — {evidence}`; leave `[ ]` for human-required items. Each `VERIFY-BY-HAND` line lands on its matching item (the `entitlement:*` lines fill `{detected .entitlements list}`; `INVENTORY|dependencies` fills `{detected SDK list}`).

**`docs/store/` hand-off (zero-token):** if `docs/store/metadata/` exists, run the lint — `bash .claude/hooks/asc-lint.sh docs/store` (or `{skills_path}/.claude/skills/appstore-connect/asc-lint.sh`) — and stamp the App Record name/subtitle line, the Required URLs lines, and the Media screenshot line `[x] verified — asc-lint passed ({date}, {locales})` when it exits 0; on errors leave `[ ]` and append `— asc-lint: {N} errors, run /appstore-connect metadata`. If `docs/store/metadata/` is absent (Step 5's IMPORT may already have created `docs/store/` for `products.md`), the Media / App Record `[ ]` lines gain the pointer `→ /appstore-connect {assets|metadata}` so the human knows the authoring lane exists. The IAP section embeds the PRODUCTS DIFF summary from Step 5.

---

## Step 7b — App Review packet

Read [review-packet.md](review-packet.md) (it sits beside this file) before drafting. It covers the eight items, the attachment mechanics, the recording rules, and the TestFlight purchase caveats.

1. **Draft** `docs/store/metadata/review_information/notes.txt`, numbered 1–8 to match the 2.1 letter, with explicit "not applicable" lines. Build it from the brief, the PRD, the Step 1–5 inventory (SDKs, permission keys, StoreKit, CloudKit, `FoundationModels` imports), and the permission call sites. Keep it ≤ 4,000 characters and move overflow to `docs/store/review-guide.md`, which is rendered to PDF for the reply.
2. **Claim ledger.** Write `docs/store/review-claims.md` as a table (`| # | claim | how to reach it on device | verified |`) with one row per navigable or permission claim in the notes. Every row starts as `UNVERIFIED`. Only the human changes a row, to `device {model} iOS {x} {date}`, after walking the claim in the running app. For permission rows, "how to reach it" is the tap that fires the call site, not the screen where the permission is conceptually used.
3. **Shot list.** Append a recording shot list to `review-guide.md`: fresh-install state, every prompt with its staged trigger, and the paywall. Multiple clips are fine.
4. **Gate (zero-token).** `asc-lint.sh` reports an oversized `notes.txt` as an ERROR and each `UNVERIFIED` row as a WARN. The checklist's review-notes line is stamped `[x]` only when both are clear. Never flip a row to verified yourself: a claim that reads correctly in source is exactly the kind that fails.

Skip this step on update submissions unless the user asks, or unless `review_information/notes.txt` is absent.

---

## Step 8 — Report

1. Print the summary table:

| Scope | BLOCKER | HIGH | MEDIUM | LOW |
|---|---|---|---|---|
| PLIST / MANIFEST / SIGNING / ASSET / CODE / BEHAVIOR | | | | |

2. State both output paths, plus the Step 7b packet paths and the `UNVERIFIED` claim count.
3. Say: "Run `/dev-story docs/maintainer/appstore-preflight-{date}.md` to fix the code/config findings. The checklist items in `appstore-submission-checklist.md` are human actions in App Store Connect — work through them before submitting; `/appstore-connect` authors the screenshots, listing copy, and product spec those items ask for. Re-run `/appstore-preflight` after fixes to confirm clean."
4. If any ⚠️VOLATILE finding was flagged (external purchase links, SDK-floor, UIRequiresFullScreen), remind the user those rules are in flux and name the one(s) to re-verify.
