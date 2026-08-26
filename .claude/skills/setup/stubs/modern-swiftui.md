## Swift/SwiftUI Guardrails (iOS 18+)

<!-- leanwheel:guardrails swift v2 — MANAGED BLOCK.
     Everything between this marker and the next `---` is re-synced by /upgrade-project.
     Do not add project-specific rules here; they belong in `## Critical Rules` above.
     This block is a POINTER plus tripwires: full patterns live in docs/setup/swift/ and are
     refreshed by /refresh-swift. Never inline a reference file's contents here — it is loaded
     every turn, and an inlined copy drifts from the file it was copied from.
-->

> **Full reference: `docs/setup/swift/`** — read the file that matches the work before writing code.
> `state-management` · `concurrency` · `architecture` · `ui-composition` · `testing` ·
> `testability` · `simulator` · `anti-patterns` · `accessibility` · `core-data-cloudkit` ·
> `localization` · `xcode-footguns` · `demo-data-and-copy` · `PROVENANCE`

### Hard Rejections — Never Use in New Code

| Banned | Replacement |
|---|---|
| `ObservableObject`, `@Published` | `@Observable` |
| `@StateObject`, `@ObservedObject` | `@State` (owned) / `@Bindable` (child) |
| `@EnvironmentObject` | `@Environment(MyService.self)` |
| `import Combine` in new files | `async/await`, `.task`, `AsyncStream` |
| `DispatchQueue` in new service code | `actor`, `async func`, `@MainActor`, `@concurrent` |
| `.onAppear { Task { } }` | `.task { }` |
| `*ViewModel.swift` for a single view | Logic as computed properties in the View |
| `TabView` with `.tabItem { }` (iOS 18+) | `Tab` wrapper with `.tabViewStyle(.sidebarAdaptable)` |
| Manual scroll offset detection (sentinel views, `PreferenceKey`) | `onScrollTargetVisibilityChange`, `onScrollGeometryChange` |
| `ForEach(0..<items.count)` on mutable data | `ForEach(items)` where `Item: Identifiable` |
| `foregroundColor()`, `cornerRadius()` | `foregroundStyle()`, `clipShape(.rect(cornerRadius:))` |
| `DateFormatter`/`NumberFormatter`/`String(format:)` | `.formatted(...)` / `FormatStyle` |
| 1-param `.onChange(of:) { new in }` | 2-param `{ old, new in }` or 0-param |
| `contains()` for user-input filtering | `localizedStandardContains()` |
| `onTapGesture` on plainly tappable content | `Button` (gesture only for location/count) |
| `Task.sleep(nanoseconds:)`, `UIScreen.main.bounds` | `Task.sleep(for:)`, `containerRelativeFrame` |
| `Array(fetchResults)` passed parent → child | `@Binding` to the source object, or the child owns its own fetch |
| `.sheet(isPresented:)` + a separately-set `@State` item | `.sheet(item: $optional) { item in … }` |
| `.sheet`/`.alert`/`.confirmationDialog` on a `Section` | Attach to the `List` or the top-level view |
| `import XCTest` in new **unit** tests | `import Testing` (UI-test targets keep XCTest — no Swift Testing UI API) |
| `simctl shutdown all` | Create your own device, target by `id=`, delete only that UDID |
| Reasoning from a screenshot to a tap coordinate | A named `--route`, a `--seed`, an `.accessibilityIdentifier` |

**`@ObservedObject` exception:** legitimate for a row/detail view receiving a single
`NSManagedObject` — Core Data objects are `ObservableObject` natively with no `@Observable`
alternative.

### Tripwires — violating these corrupts data or ships a liability

One line each; the mechanism is in the linked file. These are here rather than in a reference
file because they must be known **before** a plan is formed.

- **Core Data + CloudKit:** every attribute `optional="YES"`, generated object-typed properties
  optional (never "fixed" with `!`), no `ordered="YES"`, no uniqueness constraints, CloudKit
  options behind `#if !targetEnvironment(simulator)`. Each is a **launch crash**, and once
  deployed, a permanently wrong Production schema. → `core-data-cloudkit.md`
- **Dismiss before saving a deletion** of the object a sheet is displaying, and never drive a
  `sheet`/`fullScreenCover` from a fetch-derived Bool — a save re-renders the presentation
  against a zombie object, or yanks the cover away. → `ui-composition.md`
- **Stateful persistence mutations live in a service**, never inline in a view-lifecycle
  modifier — logic in a view is untestable, so every regression ships silently. → `anti-patterns.md` #11
- **A seeded record must look real and resolve to nobody** — `555-01xx`, `@example.com`, every
  coined street or company name searched individually, no live payment handles. `#if DEBUG` is
  not the control: fixtures end up in screenshots and docs. → `demo-data-and-copy.md`
- **Regulated copy names the purpose, never the status** — no "IRS-ready" / "compliant" /
  "audit-proof", and never let copy imply completeness. Legal exposure, not style. → `demo-data-and-copy.md`
- **`xcodebuild` needs its full path**, a fresh simulator needs `privacy grant` before `test`
  (or it hangs at 0% CPU looking like a wedged toolchain), and a green-looking log can be missing
  an entire target — score the teed unfiltered log. → `simulator.md`
- **`isHittable` lies under translucent bars** — scroll clear of the nav and tab bars first. It
  is not a timing flake and retries cannot fix it. → `simulator.md`
- **`EXCLUDED_SOURCE_FILE_NAMES = "CLAUDE.md"`** at project level, in both configurations, before
  a second nested `CLAUDE.md` exists — otherwise the build fails with "Multiple commands produce".
  → `xcode-footguns.md`

### Pre-Implementation Checklist

Before marking any story done, verify:
- [ ] Nothing from the Hard Rejections table
- [ ] Shared services injected via `@Environment(MyService.self)`, not init parameters
- [ ] View-lifecycle async uses `.task` / `.task(id:)`; persistence mutations live in a service
- [ ] Icon-only buttons have text labels; no fixed font sizes (Dynamic Type — `accessibility.md`)
- [ ] New views carry `.accessibilityIdentifier`s; a new screen carries its route
- [ ] New unit tests use `import Testing`; every new gate has been watched failing
- [ ] Build is at **zero warnings** and the test log was scored, not eyeballed

<!-- /leanwheel:guardrails swift v2 -->
