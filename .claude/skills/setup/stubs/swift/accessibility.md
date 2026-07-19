# Accessibility Rules

> Updated: 2026-07-19 — iOS 18+ (iOS 26 features flagged)
> Code-changing accessibility rules for every UI story. Semantic `.accessibilityIdentifier`s for UI testing are covered in testability.md — this file is about real users.

---

## Controls

```swift
// ✅ Icon-only buttons still get a text label — SwiftUI hides it visually
// in an icon-only context but VoiceOver reads it
Button("Add Customer", systemImage: "plus") { addCustomer() }

// ❌ Bare image button — VoiceOver announces "plus, button"
Button { addCustomer() } label: { Image(systemName: "plus") }

// ✅ Tappable content is a Button (VoiceOver trait, highlight, keyboard focus)
// Use onTapGesture ONLY when you need the tap location or count —
// and then add the trait manually:
.onTapGesture(count: 2) { zoom($0) }
.accessibilityAddTraits(.isButton)
```

- Minimum 44×44pt hit target on everything interactive (see ui-composition.md).
- Labels that change with state need `.accessibilityInputLabels([...])` so Voice Control users can still target them.

---

## Dynamic Type

```swift
// ✅ Semantic fonts scale for free
Text(order.customerName).font(.headline)

// ✅ Custom sizes must scale: @ScaledMetric (iOS 18+) …
@ScaledMetric(relativeTo: .body) private var iconSize = 24.0

// … or the scaled-font API (iOS 26+)
Text("Total").font(.body.scaled(by: 1.2))

// ❌ Fixed sizes and fixed frames on text — clip under larger type settings
Text("Total").font(.system(size: 17))
Text(name).frame(width: 120, height: 20)
```

---

## Motion, Color, Images

```swift
// ✅ Respect Reduce Motion — swap large movement for opacity/crossfade
@Environment(\.accessibilityReduceMotion) private var reduceMotion
.animation(reduceMotion ? .none : .bouncy, value: isExpanded)

// ✅ Never encode meaning in color alone — pair with a symbol/text when
// differentiate-without-color is on
@Environment(\.accessibilityDifferentiateWithoutColor) private var diffNoColor
Label(status.name, systemImage: diffNoColor ? status.symbol : "circle.fill")

// ✅ Decorative images are invisible to VoiceOver
Image(decorative: "background-texture")   // or .accessibilityHidden(true)
```

**DoD for UI stories:** icon-only controls have labels, no fixed font sizes, Reduce Motion respected on nontrivial animations, decorative images hidden. Design-token/state coverage is verified separately by design-verify.
