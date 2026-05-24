# EXPERIENCE.md Template

Behavioral contract. Visual specs live in `DESIGN.md`; cross-reference tokens with `{path.to.token}` syntax.

---

```markdown
---
name: {project_name}
status: draft   # draft | final
updated: {date}
sources:
  - docs/prd.md
---

## Foundation
[Form factors in scope. UI system (SwiftUI / shadcn / none). Visual identity reference: `docs/ux/DESIGN.md`.]
[Single sentence on design posture: calm / dense / playful / etc.]

## Information Architecture
| Surface | Reached from | Purpose |
|---|---|---|
| | | |

[Navigation structure. For Apple: tab bar pattern, NavigationStack vs NavigationSplitView per form factor.]
[→ Mockup references if any: `docs/ux/mockups/screen-name.html`]

## Voice and Tone
Microcopy. Brand voice and aesthetic posture live in `DESIGN.md`.

| Do | Don't |
|---|---|
| | |

[Rules: sentence case, active voice, sentence length limits, banned words/patterns.]

## Component Patterns
Behavioral. Visual specs live in `DESIGN.md.Components`.

| Component | Use | Behavioral rules |
|---|---|---|
| | | |

## State Patterns
| State | Surface | Treatment |
|---|---|---|
| Empty | | |
| Loading / skeleton | | |
| Error | | |
| Offline | | |
| Permission denied | | |

[Add product-specific states as needed.]

## Interaction Primitives
[Tap / click, swipe, drag, keyboard shortcut rules.
For Apple: list banned gestures (never override system swipe-back). List haptic moments.
For web: keyboard navigation contract, hover states, focus ring rules.]

## Accessibility Floor
Behavioral. Visual contrast lives in `DESIGN.md`.

**For Apple platform:**
- VoiceOver: every interactive element labeled with `.accessibilityLabel` + role + state. State transitions announce via `.accessibilityValue` or custom announcement.
- Dynamic Type: all text scales via system type roles; no truncated controls at any accessibility size.
- Reduce Motion: no essential information conveyed by animation alone; spring animations replaced with fade/instant.
- Tap targets ≥ 44×44pt everywhere.
- Focus traversal follows reading order; custom focus groups declared where needed.

**For web:**
- WCAG 2.2 AA throughout.
- Keyboard navigation: all interactive elements reachable by Tab; logical focus order.
- Focus visible: system focus ring or branded equivalent, never suppressed.
- Screen reader: landmark regions, aria-label on icon-only controls.

## Key Flows
[Named-protagonist journeys. Each flow: numbered steps + a climax beat + failure path.]
[Mirror surface/feature names verbatim from PRD.]

### Flow 1 — {Name} ({protagonist}, {context})
1. ...
**Climax:** ...
**Failure:** ...

---

## Apple Platform
[Required when Apple surfaces are in scope. See Platform Presets in skill.md for full rules.]

### Navigation
[Pattern per form factor.]

### SwiftUI Adaptive Layout
[Adaptive containers, size class usage, iPad multitasking behavior.]

### HIG Compliance Checklist
- [ ] SF Symbols used for all iconography
- [ ] Safe area insets respected
- [ ] Tap targets ≥ 44×44pt
- [ ] System color semantics used for tint, labels, backgrounds
- [ ] Dark Mode: all brand tokens defined for both appearances
- [ ] Dynamic Type: all text scales without truncation at Accessibility Extra Large
- [ ] Reduce Motion: no essential information conveyed by animation alone
- [ ] Haptics: used only at HIG-defined moments
- [ ] Context menus and swipe actions follow platform conventions
- [ ] Keyboard and pointer support on iPad / Mac

### Platform-Specific Components
| Component | SwiftUI View | Notes |
|---|---|---|
| Navigation | NavigationStack / NavigationSplitView | Per form factor |
| List | List + .listStyle(.insetGrouped) | |
| Modal | .sheet / .fullScreenCover | |
| Alert | Alert / .confirmationDialog | |
| Action menu | .confirmationDialog | |

### macOS Considerations
[If Mac is in scope: menu bar items, keyboard shortcuts, window sizing, toolbar items, Mac idiom vs Catalyst.]

---

## Responsive & Platform
[Required when web surfaces are in scope with multiple breakpoints or mobile-as-secondary behavior.]

| Breakpoint | Columns | Notes |
|---|---|---|
| sm (< 640px) | 1 | |
| md (640–1024px) | 2 | |
| lg (> 1024px) | 3–4 | |

[Primary surface (desktop/tablet/phone). Navigation delta per breakpoint. Pointer vs touch input delta.]

---

## Inspiration & Anti-patterns
[Required when user provided reference products or explicit rejects during Discovery.]

- **Lifted from [Product]:** [what and why]
- **Rejected — [Pattern]:** [why it's wrong for this product]
```
