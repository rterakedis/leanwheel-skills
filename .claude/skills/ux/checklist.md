# UX Checklist

Run during Validate flow and at Finalize. Report critical/high findings with location and fix. Summarize medium/low as a tail count.

---

## 1. Flow Coverage
- [ ] Every PRD feature / user journey has a Key Flow with: named protagonist, numbered steps, a climax beat, and a failure path.
- [ ] Every IA surface is reachable from at least one flow.
- [ ] IA closure: every stated user need maps to a surface; every surface has a journey.

**Severity if broken:** Critical (no journey) / High (missing climax or failure path)

---

## 2. Token Completeness (DESIGN.md)
- [ ] Every color token has an explicit hex value (or `note:` for platform-semantic colors).
- [ ] Light/dark pairs defined for all load-bearing color tokens.
- [ ] Every `{path.to.token}` reference in EXPERIENCE.md resolves to a token in DESIGN.md frontmatter.
- [ ] Typography tokens cover all text roles used in the product.
- [ ] Spacing scale covers all values referenced in Layout section.

**Severity if broken:** Critical (missing hex on color token used in code) / High (unresolved cross-reference)

---

## 3. Component Coverage
- [ ] Every component named anywhere has a row in DESIGN.md `## Components` (visual spec).
- [ ] Every component named anywhere has a row in EXPERIENCE.md `## Component Patterns` (behavioral spec).
- [ ] No component described with only a one-word description — must have real behavioral rules.

**Severity if broken:** High

---

## 4. State Coverage
- [ ] Every IA surface has empty, loading, error, and offline states defined (or explicit "N/A" with rationale).
- [ ] No state says "show an error" without specifying: what the message is, where it appears, and whether it blocks.

**Severity if broken:** High (missing state for primary surface) / Medium (secondary surface)

---

## 5. Apple Platform (required when Apple surfaces in scope)
- [ ] HIG Compliance Checklist in EXPERIENCE.md `## Apple Platform`: every item resolved as ✓, –, or [OPEN].
- [ ] No [OPEN] items remain at `status: final`.
- [ ] SwiftUI component map covers all major components.
- [ ] Navigation pattern specified per form factor (iPhone / iPad / Mac).
- [ ] Safe area insets addressed in Layout & Spacing.
- [ ] System color semantics (`.primary`, `.secondarySystemBackground`, etc.) used in DESIGN.md where appropriate — not hardcoded hex for system colors.
- [ ] Multi-target cascade documented if more than one Apple surface is in scope.
- [ ] macOS section present if Mac is in scope (menu bar, keyboard shortcuts, window sizing).

**Severity if broken:** Critical (HIG items unresolved at final) / High (missing platform section) / Medium (incomplete SwiftUI map)

---

## 6. Web / Responsive (required when web surfaces in scope)
- [ ] `## Responsive & Platform` section present with named breakpoints.
- [ ] Navigation behavior at each breakpoint defined.
- [ ] WCAG 2.2 AA stated as the accessibility floor.
- [ ] Keyboard navigation contract present in Interaction Primitives.

**Severity if broken:** High (missing breakpoints) / Medium (missing keyboard contract)

---

## 7. Content Site / SSG (required when the SSG preset is in scope)
- [ ] `## Content & Performance` section present in EXPERIENCE.md.
- [ ] Every content type maps to a layout + listing surface + URL pattern.
- [ ] Performance budget stated (CWV target, per-page-type JS budget); every planned island/script named and justified.
- [ ] Typography tokens include fluid scale values and reading measure.
- [ ] Dark mode mechanism stated (`prefers-color-scheme`, with/without manual toggle).
- [ ] SEO/meta decisions present: title pattern, OG image approach, RSS scope.

**Severity if broken:** High (missing performance budget or content-type mapping) / Medium (missing SEO decisions)

---

## 8. Engagement & Persuasion
- [ ] `## Engagement & Persuasion` section present, or an explicit `N/A — no onboarding/conversion/retention surface` note.
- [ ] Every lever used names the flow it applies to and carries an honesty check (aligns the user's interest with the business's).
- [ ] Smart defaults pre-select the choice most users actually want — never the most profitable / highest-commitment option by default.
- [ ] Goal-gradient progress is real and earned — no fake, pre-filled, or endowed progress.
- [ ] No dark patterns: no pre-checked paid/consent opt-ins, manufactured urgency/scarcity, guilt-decline (confirmshaming) copy, or decoy pricing.

**Severity if broken:** Critical (a shipped dark pattern) / High (lever with no honesty check) / Low (missing section on a tool with no conversion surface)

---

## 9. Bloat & Overspecification
- [ ] No pixel values in EXPERIENCE.md where a DESIGN.md token covers it.
- [ ] No PRD content restated (personas, FRs, scope) — inherited by reference only.
- [ ] No decorative prose in EXPERIENCE.md untied to a behavioral decision.
- [ ] Tables used where tables are clearer than prose.

**Severity if broken:** Medium (readability) / Low (minor redundancy)

---

## 10. Shape
- [ ] DESIGN.md sections in canonical order: Brand & Style → Colors → Typography → Layout & Spacing → Elevation & Depth → Shapes → Components → Do's and Don'ts. (Omittable; order locked when present.)
- [ ] EXPERIENCE.md required sections present: Foundation · IA · Voice and Tone · Component Patterns · State Patterns · Interaction Primitives · Accessibility Floor · Key Flows · Engagement & Persuasion (or its N/A note). Dropped sections have a stated reason.
- [ ] Conditional sections present when triggered: Apple Platform (any Apple surface) · Responsive & Platform (web with breakpoints) · Inspiration & Anti-patterns (user provided references or rejects).

**Severity if broken:** Medium (missing conditional section) / Low (order violation)
