## Swift/SwiftUI Guardrails (iOS 18+)

> Updated: 2026-07-19 — iOS 18+ / Swift 6.2 (iOS 26 features gated with `#available`)

Full reference patterns live in `docs/setup/swift/`. This section contains only the always-active hard rules.

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

### Property Wrapper Quick Reference

| Situation | Use |
|---|---|
| View-private transient state (sheet flag, search text, form field) | `@State` |
| Pass mutable access to a child view | `@Binding` |
| Bind to a property on an `@Observable` object in a child view | `@Bindable` |
| Shared app/feature-level service | `@Environment(MyService.self)` |
| Core Data query results owned by the rendering view | `@FetchRequest` |
| Persistent cross-launch UI state | `@SceneStorage` / `@AppStorage` |
| Custom environment value key (iOS 18+) | `@Entry` macro in `EnvironmentValues` extension |

### Pre-Implementation Checklist

Before marking any story done, verify:
- [ ] No `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`
- [ ] No new `*ViewModel.swift` file created to serve a single view
- [ ] Shared services injected via `@Environment(MyService.self)`, not init parameters
- [ ] View-lifecycle async uses `.task` or `.task(id:)`, not `.onAppear { Task { } }`
- [ ] No deprecated APIs from the rejection table (`foregroundColor`, `DateFormatter`, 1-param `onChange`, …)
- [ ] `ForEach` over `Identifiable` items, never index-based ranges on mutable data
- [ ] Icon-only buttons have text labels; no fixed font sizes (Dynamic Type — see `accessibility.md`)
- [ ] New tests use `import Testing`, not `import XCTest`

> Full patterns, code examples, and architecture guidance: `docs/setup/swift/`
