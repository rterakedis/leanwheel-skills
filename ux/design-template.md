# DESIGN.md Template

Per the [Google Labs design.md spec](https://github.com/google-labs-code/design.md). YAML frontmatter carries machine-readable tokens; markdown body carries the human-readable rationale.

---

```markdown
---
name: {project_name}
description: {one-line brand statement}
status: draft   # draft | final
updated: {date}
sources:
  - docs/prd.md
colors:
  # Required for brand tokens — always explicit hex.
  # For Apple platform: also define semantic aliases that map to SwiftUI system colors.
  # Light/dark pairs: use -{dark} suffix (e.g. surface-base / surface-base-dark).
  primary: ''
  primary-dark: ''
  surface-base: ''
  surface-base-dark: ''
  # ... add tokens as needed
typography:
  # For web: explicit fontFamily / fontSize / fontWeight / lineHeight.
  # For Apple platform: use note: field for system type roles; add custom brand fonts if any.
  # Example (Apple): title: { note: 'SF Pro — iOS .title / Title 1' }
  # Example (web):   body: { fontFamily: 'Inter', fontSize: '16px', lineHeight: '1.5' }
rounded:
  sm: ''
  md: ''
  lg: ''
spacing:
  '1': 4px
  '2': 8px
  '3': 12px
  '4': 16px
  '5': 24px
  '6': 32px
  '7': 48px
  '8': 64px
components:
  # Per-component token overrides. Reference frontmatter via {path.to.token}.
  # button-primary:
  #   background: '{colors.primary}'
  #   radius: '{rounded.md}'
---

## Brand & Style
[Aesthetic posture in prose. What kind of thing is this? What feeling should it leave? What does it reject?]

## Colors
[Per-color story: why each exists, where it's used, what it's NOT used for. Cover light and dark for each load-bearing token.]

## Typography
[Type roles, scale, and rules. For Apple platform: note which roles inherit system fonts and why any custom font is justified.]

## Layout & Spacing
[Spacing scale narrative, grid behavior, margins, gutters.
For web: named breakpoints (sm / md / lg / xl) and column count at each.
For Apple: 8pt grid, safe area inset handling, platform margin conventions (iOS 16pt, iPadOS 20pt).]

## Elevation & Depth
[Shadow language and tonal layering. What creates hierarchy — layout and type, or shadow?]

## Shapes
[Corner radii rules and the aesthetic logic behind them. For Apple: no custom shapes that conflict with system sheet/card patterns.]

## Components
[Per-component visual specs: anatomy, color usage, sizing, state appearance (default / hover / pressed / disabled / focused).
For Apple: note the SwiftUI view each component maps to.]

## Do's and Don'ts
| Do | Don't |
|---|---|
| | |
```
