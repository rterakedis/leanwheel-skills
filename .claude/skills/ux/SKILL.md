---
name: ux
description: Plan UX design and produce DESIGN.md + EXPERIENCE.md. Use when the user wants to create, update, or validate UX/design specs.
---

# UX Skill

**Goal:** Produce two peer design contracts — `DESIGN.md` (visual identity: how it looks) and `EXPERIENCE.md` (IA, behavior, states, interactions, accessibility: how it works) — that give every dev session unambiguous, consistent guidance.

**Your role:** Facilitator who elicits the user's vision. Never impose colors, patterns, or directions. Probe like a senior UX practitioner; the picks are always the user's.

**Primary design surfaces:** responsive web apps and Apple platforms (iOS · iPadOS · macOS). Android is a future surface; note Android parity gaps as `[FUTURE: Android]` when discovered.

## Activation

1. Check `docs/ux/` for existing `DESIGN.md` / `EXPERIENCE.md` → detect intent: **Create**, **Update**, or **Validate**. Ask if unclear.
2. Read `docs/prd.md` if present (silently — no summary). Read `docs/architecture.md` if present.
3. Read `docs/project/` for any brand, platform, or design inputs. Surface found files; confirm with user before reading.
4. Greet: "Found: [list]. Anything else before we start?"

## Platform Presets

Before Discovery begins, resolve the platform surface. Ask once if not clear from PRD or first message:

> "What platforms are we designing for? (e.g. responsive web app, content site / SSG like Astro or Hugo, iOS, iPadOS, macOS, or a combination)"

Then apply the matching preset below. On multi-platform, apply all that match.

### Web app preset
- UI system candidates: shadcn/ui + Tailwind, MUI, or none (custom).
- **When a named UI system is in scope, DESIGN.md specifies only the delta** — brand tokens that override the system's defaults (primary color, radius scale, type family). Don't restate values the system already provides; unlisted tokens inherit from the system as-is.
- DESIGN.md tokens: explicit hex colors, px spacing scale, named breakpoints.
- EXPERIENCE.md must include **Responsive & Platform** section (breakpoints, mobile-as-secondary-surface rules, keyboard/pointer interaction delta).
- Accessibility floor: WCAG 2.2 AA.

### Content site (SSG) preset — Astro, Hugo, and similar
Use when the product is primarily content (blog, docs, marketing, portfolio) built with a static site generator. Differs from the web app preset in what's load-bearing:
- **Typography first.** The type system carries the design: fluid scale (`clamp()` values as tokens), reading measure (~65ch), vertical rhythm. Probe typography before color.
- **Tokens:** CSS custom property names alongside hex values (e.g. `--color-primary`), light/dark pairs mandatory, dark mode via `prefers-color-scheme` (state explicitly if a manual toggle is also required).
- **Content model → layout mapping.** EXPERIENCE.md IA maps each content type (post, doc page, project, landing) to a layout, listing surface, and URL pattern. This replaces app-style screen flows.
- **Performance budget is a design decision.** EXPERIENCE.md must state it: Core Web Vitals green; JS budget per page type (default: zero JS on content pages — every island/script must be named and justified here, at design time).
- **SEO/meta as design surface:** OG image template, title patterns, RSS scope — decided here, not improvised per page.
- EXPERIENCE.md must include a **Content & Performance** section covering the four bullets above.
- Accessibility floor: WCAG 2.2 AA.

### Apple platform preset
- UI system: SwiftUI. DESIGN.md tokens use `note:` fields for Apple-native type roles and spacing (e.g. `note: 'iOS Title 1 / .title'`). Hex colors still required for brand tokens; system colors reference by semantic name (`.primary`, `.secondarySystemBackground`, etc.).
- EXPERIENCE.md must include **Apple Platform** section (see rules below).
- Accessibility floor: Dynamic Type at all sizes, VoiceOver full traversal, Reduce Motion honored.
- Multi-target cascade: when designing for more than one Apple surface, call out iPhone → iPad → Mac layout transitions explicitly (`.navigationStack` → `.navigationSplitView`, sidebar behavior, menu bar, etc.).

**Apple Platform section rules (EXPERIENCE.md):**

```
## Apple Platform

Form factors in scope: [iPhone | iPad | Mac | combinations]

### Navigation
- Navigation pattern per form factor (stack, split view, tab bar, sidebar).
- iPhone: NavigationStack with tab bar (≤5 tabs). iPad: NavigationSplitView with sidebar. Mac: NavigationSplitView or menu bar.
- Swipe-back honored everywhere; no custom back gestures.

### SwiftUI Adaptive Layout
- Adaptive containers used (LazyVGrid, ViewThatFits, etc.) and breakpoints.
- Size classes relied on (compact/regular width, compact/regular height).
- iPad multitasking: behaviors in Split View and Slide Over.

### HIG Compliance Checklist (required)
Per the Apple Human Interface Guidelines. Mark each: ✓ addressed in spines | – not applicable | [OPEN] needs decision.
- [ ] SF Symbols used for all iconography (no third-party icon sets unless HIG exception stated)
- [ ] Safe area insets respected (no content clipped by notch, Dynamic Island, home indicator)
- [ ] Tap targets ≥ 44×44pt
- [ ] System color semantics used for tint, labels, backgrounds (no hardcoded system color values)
- [ ] Dark Mode: all brand tokens defined for both appearances
- [ ] Dynamic Type: all text scales without truncation at Accessibility Extra Large
- [ ] Reduce Motion: no essential information conveyed by animation alone
- [ ] Haptics: used only at HIG-defined moments (impact, notification, selection feedback)
- [ ] Context menus and swipe actions follow platform conventions
- [ ] Keyboard and pointer support on iPad / Mac (keyboard shortcuts, hover states)

### Platform-Specific Components
Map each major UI component to its SwiftUI equivalent. Example:
| Component | SwiftUI View | Notes |
|---|---|---|
| Navigation | NavigationStack / NavigationSplitView | Per form factor |
| List | List + .listStyle | Inset grouped on iOS |
| Modal | .sheet / .fullScreenCover | |
| Alert | Alert / .confirmationDialog | |
| Action sheet | .confirmationDialog | Sheet on iPad |

### macOS Considerations (if in scope)
- Menu bar items and keyboard shortcuts (⌘ equivalents for all primary actions).
- Window sizing: minimum size, resizability, toolbar items.
- Catalyst vs native SwiftUI Mac idiom (prefer native Mac idiom).
```

## Working Modes

Offer the choice; default to Fast path if the user doesn't specify.

**Fast path** — Batch remaining gaps into 1–2 consolidated questions. Draft both spines with `[ASSUMPTION: …]` tags where inferred. User reviews and iterates. Best when user gave a lot upfront.

**Coaching path** — Walk through Discovery sections together. Ask open-ended "tell me about X" questions; never name answers or present multiple-choice lists.

## Create Flow

### Step 1 — Brain dump
Ask user to describe the product's UX vision. One prompt.

### Step 2 — Stakes calibration
One question: hobby / internal tool / consumer / regulated?

### Step 3 — Platform surface
Apply Platform Presets above.

### Step 4 — Discovery

**Capture; never author.** Decisions go into `.decision-log.md`. Creative artifacts go in `docs/ux/.working/`.

Work through these areas. Batch in Fast path; walk one-by-one in Coaching path:

- **Tone & brand posture.** What feeling should the product leave? Any brand references (apps, sites the user admires or wants to avoid)?
- **Color direction.** Probe with open questions: "Warm or cool? Loud or restrained? Light or dark default?" Render an HTML color palette mock if it would help the user decide (see Visual Aids below).
- **Typography.** For web: serif or sans? For Apple: lean on system fonts (SF Pro / SF Rounded / New York) unless a custom brand font is justified. Ask.
- **Information architecture.** What are the main surfaces? How does the user move between them? Walk a named protagonist through a real session — "Tell me about [Name], who uses this for the first time."
- **Platform concerns.** Name what this UX carries: accessibility, offline, dark mode, notifications, keyboard support, pointer/hover, content density, i18n, regulated copy.
- **Engagement levers.** For the *high-leverage flows only* (onboarding, forms/setup, upgrade/paywall, destructive or irreversible actions), probe which behavioral levers apply **honestly**: smart defaults (pre-pick the option most users actually want), goal gradient (show *real, earned* progress in onboarding/multi-step flows), reciprocity (deliver value before the ask), loss framing (only where the loss is genuine — data, security, real expiry), contrast/anchoring (only where the comparison aids a real decision). For each lever used, capture the **honesty check** — the one line explaining how it aligns the user's interest with the business's. A lever that serves only the business is a dark pattern (pre-checked paid/consent opt-ins, fake or endowed progress, manufactured urgency/scarcity, guilt-decline copy, decoy pricing): reject it and record the rejection. This is a deliberate per-flow decision, never default-on — it lands in EXPERIENCE.md's **Engagement & Persuasion** section. Skip entirely for internal tools with no conversion/retention surface (record that as the N/A note).
- **Inspiration & anti-patterns.** What should this feel like? What patterns should it explicitly reject?

IA closes when every stated need has a surface that delivers it, and every surface has a journey that lands there. If closure fails, probe — never invent the missing piece.

### Step 5 — Visual aids (on demand)

Render inline HTML when it would help the user decide. Offer proactively at:
- Color direction (color swatches with light/dark mode examples)
- Key screen layout (simple HTML mock of 1–2 critical surfaces)
- Component visual (if the user is unsure what a pattern looks like)

Write artifacts to `docs/ux/.working/` with descriptive filenames. Open in browser with:
```
python3 -c "import webbrowser, pathlib; webbrowser.open(pathlib.Path('docs/ux/.working/FILENAME').resolve().as_uri())"
```

Keep mocks simple — layout and color intent, not pixel-perfect production UI. For Apple platform, use proportional iPhone/iPad frames in HTML to convey layout intent; note this is not a SwiftUI preview.

### Step 6 — Write spines

Apply the templates in `design-template.md` and `experience-template.md`.

Rules:
- Never duplicate content from the PRD — inherit by reference.
- EXPERIENCE.md cross-references DESIGN.md tokens using `{path.to.token}` syntax.
- Tag every inference: `[ASSUMPTION: …]`.
- Drop any section that doesn't earn its place. Add sections the product genuinely needs.
- For Apple platform: populate the **Apple Platform** section fully. Every HIG checklist item must be resolved (✓, –, or [OPEN]) before the spines are marked `status: final`.

### Step 7 — Finalize

1. Triage `[ASSUMPTION]` tags. Resolve phase-blockers; log others.
2. Resolve all `[OPEN]` items in the HIG checklist (Apple platform) or Responsive breakpoints (web).
3. **Mock coverage confirmation:** walk every IA surface named in EXPERIENCE.md and classify each as mocked (a visual aid exists for it) or spine-only (tables/prose alone). For any spine-only surface, ask once: "These will be built from spine tables alone — any need a visual reference?" Log the answer either way so closure isn't silently skipped.
4. Run the checklist in `checklist.md`. Surface critical/high findings only.
5. Write `docs/ux/DESIGN.md` and `docs/ux/EXPERIENCE.md`.
6. Set `status: final` and `updated: {date}` in both frontmatters.
7. Output: file paths + next step (`/architecture` if not done, or `/epics`).

## Update Flow

1. Read `docs/ux/DESIGN.md` and `docs/ux/EXPERIENCE.md`.
2. Read the change signal (user message, updated PRD, etc.).
3. Surface conflicts with prior decisions before applying.
4. Apply. Re-triage `[ASSUMPTION]` tags and HIG checklist items.
5. Save. Output: what changed + "Run `/architecture` if structural platform decisions changed."

## Validate Flow

1. Read `docs/ux/DESIGN.md` and `docs/ux/EXPERIENCE.md`.
2. Run checklist in `checklist.md` across all dimensions.
3. Report: one-sentence verdict, then critical/high findings with locations and fixes. Medium/low as a tail count.
