# UX Presets & Discovery Areas

Loaded by `/spec` when the target is `ux`. Platform presets pick what's load-bearing in
DESIGN.md/EXPERIENCE.md; the discovery areas are the decision surface — each one either has
backing decisions in the log or is elicited before its section renders.

**Primary design surfaces:** responsive web apps and Apple platforms (iOS · iPadOS · macOS).
Android is a future surface; note parity gaps as `[FUTURE: Android]` when discovered.

## Platform Presets

Resolve the platform surface before rendering. Ask once if not clear from the log, the PRD,
or the manifest:

> "What platforms are we designing for? (e.g. responsive web app, content site / SSG like
> Astro or Hugo, iOS, iPadOS, macOS, or a combination)"

On multi-platform, apply all that match.

### Web app preset
- UI system candidates: shadcn/ui + Tailwind, MUI, or none (custom).
- **When a named UI system is in scope, DESIGN.md specifies only the delta** — brand tokens
  that override the system's defaults (primary color, radius scale, type family). Don't
  restate values the system already provides; unlisted tokens inherit from the system as-is.
- DESIGN.md tokens: explicit hex colors, px spacing scale, named breakpoints.
- EXPERIENCE.md must include **Responsive & Platform** section (breakpoints,
  mobile-as-secondary-surface rules, keyboard/pointer interaction delta).
- Accessibility floor: WCAG 2.2 AA.

### Content site (SSG) preset — Astro, Hugo, and similar
Use when the product is primarily content (blog, docs, marketing, portfolio) built with a
static site generator. Differs from the web app preset in what's load-bearing:
- **Typography first.** The type system carries the design: fluid scale (`clamp()` values as
  tokens), reading measure (~65ch), vertical rhythm. Probe typography before color.
- **Tokens:** CSS custom property names alongside hex values (e.g. `--color-primary`),
  light/dark pairs mandatory, dark mode via `prefers-color-scheme` (state explicitly if a
  manual toggle is also required).
- **Content model → layout mapping.** EXPERIENCE.md IA maps each content type (post, doc
  page, project, landing) to a layout, listing surface, and URL pattern. This replaces
  app-style screen flows.
- **Performance budget is a design decision.** EXPERIENCE.md must state it: Core Web Vitals
  green; JS budget per page type (default: zero JS on content pages — every island/script
  must be named and justified here, at design time).
- **SEO/meta as design surface:** OG image template, title patterns, RSS scope — decided
  here, not improvised per page.
- EXPERIENCE.md must include a **Content & Performance** section covering the four bullets
  above.
- Accessibility floor: WCAG 2.2 AA.

### Apple platform preset
- UI system: SwiftUI. DESIGN.md tokens use `note:` fields for Apple-native type roles and
  spacing (e.g. `note: 'iOS Title 1 / .title'`). Hex colors still required for brand tokens;
  system colors reference by semantic name (`.primary`, `.secondarySystemBackground`, etc.).
- EXPERIENCE.md must include **Apple Platform** section (rules below).
- Accessibility floor: Dynamic Type at all sizes, VoiceOver full traversal, Reduce Motion
  honored.
- Multi-target cascade: when designing for more than one Apple surface, call out iPhone →
  iPad → Mac layout transitions explicitly (`.navigationStack` → `.navigationSplitView`,
  sidebar behavior, menu bar, etc.).

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

## Discovery areas (the UX decision surface)

Each area either has backing log decisions or gets one bounded `elicit` pass before its
section renders:

- **Tone & brand posture.** What feeling should the product leave? Brand references the user
  admires or wants to avoid?
- **Color direction.** "Warm or cool? Loud or restrained? Light or dark default?" Render an
  HTML palette mock if it would help the user decide (Visual aids below).
- **Typography.** Web: serif or sans? Apple: lean on system fonts (SF Pro / SF Rounded /
  New York) unless a custom brand font is justified.
- **Information architecture.** Main surfaces and movement between them. Walk a named
  protagonist through a real session. IA closes when every stated need has a surface that
  delivers it, and every surface has a journey that lands there — if closure fails, elicit;
  never invent the missing piece.
- **Platform concerns.** Accessibility, offline, dark mode, notifications, keyboard support,
  pointer/hover, content density, i18n, regulated copy.
- **Engagement levers.** For the *high-leverage flows only* (onboarding, forms/setup,
  upgrade/paywall, destructive or irreversible actions), probe which behavioral levers apply
  **honestly**: smart defaults, goal gradient (real, earned progress only), reciprocity
  (value before the ask), loss framing (only where the loss is genuine), contrast/anchoring
  (only where the comparison aids a real decision). For each lever used, capture the
  **honesty check** — the one line explaining how it aligns the user's interest with the
  business's. A lever that serves only the business is a dark pattern (pre-checked
  paid/consent opt-ins, fake or endowed progress, manufactured urgency/scarcity,
  guilt-decline copy, decoy pricing): reject it and record the rejection. Deliberate
  per-flow decision, never default-on — lands in EXPERIENCE.md's **Engagement & Persuasion**
  section. Skip entirely for internal tools with no conversion/retention surface (record the
  N/A note).
- **Inspiration & anti-patterns.** What should this feel like? What patterns does it
  explicitly reject?

## Visual aids (on demand)

Render inline HTML when it would help the user decide — offer proactively at color direction,
key screen layout (1–2 critical surfaces), and unfamiliar component patterns. Write artifacts
to `docs/ux/.working/` with descriptive filenames; open with:

```
python3 -c "import webbrowser, pathlib; webbrowser.open(pathlib.Path('docs/ux/.working/FILENAME').resolve().as_uri())"
```

Keep mocks simple — layout and color intent, not pixel-perfect production UI. For Apple
platform, use proportional iPhone/iPad frames in HTML to convey layout intent; note this is
not a SwiftUI preview.
