# ASSETS — framed screenshots at exact store sizes

Read by `/appstore-connect assets` after SKILL.md Step 0.

**Requires**, beyond SKILL.md's: `scripts/sim.sh` (Apple projects scaffolded by `/setup`;
`/upgrade-project` adds it) and the app's `--route` / `--seed` launch-argument contract from
`docs/setup/swift/testability.md`. Absent → stop with the one-line fix; never fake a capture.

**Why probe capability, not the file.** `sim.sh` is vendored — copied into a project once, only
when missing — so a stale copy is the normal steady state, and a copy predating `--store` /
`--locale` fails this op with a confusing downstream error. Grep for each mode this op invokes
rather than comparing versions: it cannot drift from what the op calls, and it stays honest about
a locally-modified copy that still supports them (DD-46).

**Store facts** (refreshed by `/refresh-swift` Step 4): only **6.9" iPhone** and **13" iPad** are
required; App Store Connect scales those down to every smaller class. Accepted sizes: iPhone 6.9"
`1320×2868` / `1290×2796`; iPad 13" `2064×2752` / `2048×2732` (landscape = swapped).

**`compose.swift`** (beside SKILL.md) —
`swift compose.swift --locale en-US [--store-dir docs/store] [--captures .leanwheel/sim/store] [--only id,id] [--dry-run]`.
Plan × devices → framed, captioned PNGs at exact store size. Validates *everything* first and
writes nothing on any error. Styling is the optional `{store-dir}/template.json` (step 3b); with no
template it renders the built-in plain style unchanged. A full (non-`--only`, non-`--dry-run`) run
**clears the locale's stale output first** — files matching its own `{order}_{class}_{id}.png`
pattern that the current plan won't rewrite — so a reordered/renamed/deleted plan row can't leave
an orphan. Never hand-`rm` the output dir.

## Pipeline

Pipeline: `sim.sh shots --store` (one call per plan row → native captures, light+dark, `--seed heavy`, `-AppleLanguages` per locale) → `compose.swift` (bezel from `docs/store/frames/` + caption from the locale's `screenshot-captions.txt` → exact size) → `docs/store/screenshots/{locale}/`. Composition needs no judgment; the **plan file is the human review gate**.

1. **Preconditions (hard stops, one report):** `scripts/sim.sh` supports every mode this op invokes — `for m in --store --locale --assetcapture; do grep -q -- "$m" scripts/sim.sh || echo "$m"; done` must print nothing; anything printed is missing → stop with `ASSETS: scripts/sim.sh is missing {list} — run /upgrade-project to sync scripts/sim.sh` (see *Why probe capability* below). Then `scripts/sim.sh doctor` passes; `.leanwheel/sim.json` has `store_devices` (missing → `rm .leanwheel/sim.json && scripts/sim.sh doctor` to re-derive; the defaults are iPhone 17 Pro Max / iPad Pro 13-inch (M5) — both must exist in Simulator; edit if not); `docs/store/frames/iphone69.png` and (universal apps) `ipadPro13.png` exist. **Frames are user-supplied:** export a bezel PNG with a *transparent screen cutout* from Apple Design Resources (https://developer.apple.com/design/resources/ — Product Bezels), one per class, portrait; add `{class}-landscape.png` for landscape rows; `frames.json` (`{"iphone69": {"screen": [x,y,w,h]}}`) only if auto-detection of the cutout fails. Do not proceed to capture without them — a caption-only or bezel-less set is not what this op produces.
2. **Draft the plan** — `docs/store/screenshots.md`, 5–8 rows, from EXPERIENCE.md's primary flows + PRD value props. Benefit-first: the first three shots carry the pitch (outcome, core action, proof), later shots cover breadth; paywall last unless the product *is* the subscription; one dark-appearance row is enough. Each row names the **route** and **seed** the app already supports (`testability.md`'s route table / `SeedScenario`s — never invent one; a route the app lacks becomes a one-line "add route X" note, not a fake row).

   ```markdown
   | # | id | route | seed | appearance | orientation | devices |
   |---|----|-------|------|------------|-------------|---------|
   | 1 | home | home | heavy | light | portrait | iphone69,ipadPro13 |
   ```
   Write the caption strings to `metadata/{locale}/screenshot-captions.txt` (`home: See every job at a glance`) — ≤ 40 chars, a benefit not a feature name, sentence case, no trailing period. A line may carry an optional **subtitle** after a `|` (`home: See every job at a glance | Sorted by drive time`); the subtitle renders only where `template.json` gives it a slot, and **a missing subtitle is legal** (its slot is simply left empty). A missing *caption* is still an error. **Stop here for review**: "Edit the plan/captions if you want, then say continue." Composition is deterministic after this; the words are the only judgment.
3. **Capture** — one `shots --store` call per row, per locale:
   ```bash
   scripts/sim.sh shots {id} --store --route {route} --seed {seed} --locale {locale} \
     --devices {devices} --appearances {appearance} [--orientation landscape]
   ```
   `--store` forces native pixels, `large` text size only, verifies each capture's pixel size against the accepted table and **dies** on a non-6.9"/13" device. It also runs in **release-parity mode automatically** (implies `--assetcapture`), so DEBUG-only affordances the shipped app lacks cannot reach a store screenshot (Guideline 2.3.3) — the app must honour the flag via `LaunchArguments.showsDebugAffordances` (`docs/setup/swift/testability.md` ▸ `--assetcapture`). If a capture still shows a developer-only control, the app side is missing, not the script. A capture that looks like the launch screen is a dropped route until proven otherwise (`docs/setup/swift/simulator.md` ▸ When it goes wrong).
3b. **Styling (optional)** — `docs/store/template.json`. **Absent, empty, or not mentioned by the user ⇒ do nothing**: compose renders its built-in plain style (neutral background, centred caption, device fitted below it), byte for byte what it has always produced. Only create one when the project actually wants its brand in the screenshots; never scaffold an empty one "to be filled in later", and never copy another project's — this file is the *only* place a project's colours live, and `compose.swift` is shared by every project via symlink.

   Present ⇒ merged over the defaults **per key**, so overriding `colors.light.background` alone is valid and leaves everything else at its default. What it can set:

   | Group | Keys |
   |---|---|
   | `colors.{light,dark}` | `background` `caption` `subtitle` `panel` `lockup` — opaque `#RRGGBB` |
   | `lockup` | `enabled` `text` `icon.{light,dark}` (paths relative to the store dir) `iconCornerRadiusFraction` |
   | `caption` / `subtitle` | `align` (left\|center\|right) `maxLines` `maxChars` `weight` |
   | `autoShrink` | `step` `floor` — caption and subtitle shrink **independently** |
   | `panel` / `device` / `shadow` | `panel.{enabled,bleedsToBottom}` · `device.{bleedsOffBottom,clipCaptureToBezel}` · `shadow.{enabled,opacityLight,opacityDark}` |
   | `geometry.{iphone69,ipadPro13}` | per-class layout — **every value is a fraction of canvas W or H, never a pixel** (the two classes differ too much in aspect for pixels to carry); leading/tracking are multiples of the font size |

   Two behaviours are opt-in because no number expresses the old layout: setting `deviceTop` + `deviceWidth` **pins** the device (it may bleed off the bottom and clip) instead of fitting it below the caption, and setting `textBlockTop` + `textBlockBottom` gives the caption and subtitle **fixed slots** so the subtitle — and therefore the device — sits at the same height across the whole set instead of reflowing.

   A malformed template is a **hard, named error that writes nothing** — an unknown key (i.e. a typo), a bad type, a fraction outside 0…1, a bad hex colour, or a missing icon file each name their own dotted path. It never silently falls back to the plain style. Validate cheaply with `compose.swift --dry-run` (or `asc-lint.sh`) before a real run.

4. **Compose** — `swift {skills_path}/.claude/skills/appstore-connect/compose.swift --locale {locale} --dry-run`, then without `--dry-run`. All-or-nothing: any missing capture / frame / caption is listed in one report and nothing is written. Outputs `docs/store/screenshots/{locale}/{#}_{class}_{id}.png`, exact size. The full run prunes stale output for that locale before writing (reported as `compose: removed N stale screenshots`), so the directory always matches the plan — do **not** `rm -rf` it first.
5. **Verify + lint** — open two outputs with the Read tool (caption legible, bezel aligned, no launch screen); run `asc-lint.sh --locale {locale}` (checks sizes, ≤ 10 per class, and warns on any screenshot with no matching `screenshots.md` row — an orphan from a hand-composed or pre-prune run).
6. **Previews (optional, on request):** record while a flow runs — `xcrun simctl io <udid> recordVideo --codec h264 docs/store/previews/{locale}/{id}.mp4 &` then `scripts/sim.sh flow <FlowName>`; stop the recording with SIGINT. Real footage only (no post-processing beyond trimming); App Store preview lengths 15–30 s. Not automated in v1.
7. **Return:** `ASSETS: {locale} — {N} screenshots ({classes}); plan rows {R}; missing routes {list|none}`.
