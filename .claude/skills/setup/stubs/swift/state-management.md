# State Management & Data Flow

> Updated: 2026-07-19 — iOS 18+
> Source of truth for observation, data flow, and property wrapper selection.

---

## The Foundational Principle

SwiftUI views are already the ViewModel. A `View` struct holds `@State`, computes derived values as properties, and declares layout — that is the ViewModel job. Do not create a separate class to mirror this. Every `*ViewModel.swift` file you reach for is a sign the logic should either live directly in the View, in a pure function on a Service struct, or in a shared `@Observable` store.

---

## `@Observable` — When to Use It

`@Observable` is for **shared, reference-type stores and services** — objects whose state must outlive a single view or be shared across the view tree.

**Correct uses:** App-level services (`SubscriptionService`, `AuthService`), feature-level stores shared by multiple sibling views, long-lived async engines (StoreKit, CloudKit, network monitors).

**Incorrect uses:** A class that exists solely to serve one `*View.swift` file; a class whose properties mirror `@FetchRequest` results; a class that holds form field strings.

---

## Injection Pattern — Always `@Environment`, Never Init Parameters

```swift
// ✅ App root creates and injects once
@State private var subscriptionService = SubscriptionService()
ContentView().environment(subscriptionService)

// ✅ Any descendant pulls from environment — no prop-drilling
@Environment(SubscriptionService.self) private var subscriptionService

// ❌ Never pass services through init parameters
struct ChildView: View {
    let subscriptionService: SubscriptionService  // wrong
}
```

---

## Property Wrapper Selection

| Situation | Correct | Wrong |
|---|---|---|
| View-private transient UI state (sheet flag, search text, form field, toggle) | `@State` | `@StateObject`, `@ObservedObject` |
| Pass mutable access to a child view | `@Binding` | Passing array snapshots |
| Bind to a property on an `@Observable` object received by a child view | `@Bindable` | `@ObservedObject` |
| Inject a shared app/feature-level service | `@Environment(MyService.self)` | `@EnvironmentObject` |
| Own Core Data query results in the rendering view | `@FetchRequest` | Passing `FetchedResults` as Array to children |
| Persistent cross-launch UI state (tab, scroll position) | `@SceneStorage` / `@AppStorage` | `@State` with manual UserDefaults |
| Custom environment value key | `@Entry` macro (iOS 18+) | Manual `EnvironmentKey` struct boilerplate |

**Never use:** `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`. These are iOS 14–16 patterns fully superseded by `@Observable` + `@Environment`.

**`@ObservedObject` exception:** Core Data `NSManagedObject` subclasses implement `ObservableObject` directly — there is no `@Observable`-compatible alternative. Use `@ObservedObject` only for individual row/detail views that receive a single managed object from a parent's `@FetchRequest`.

---

## `@Bindable` — Bindings to `@Observable` Properties in Child Views

`@Bindable` is for child views that receive an `@Observable` object and need to create `$property` bindings to its properties. The parent passes the object; the child wraps it with `@Bindable`.

```swift
@Observable final class ProfileModel {
    var name: String = ""
    var bio: String = ""
}

// ✅ Child view uses @Bindable to create bindings
struct ProfileEditForm: View {
    @Bindable var model: ProfileModel  // receives the object, creates bindings

    var body: some View {
        TextField("Name", text: $model.name)
        TextField("Bio", text: $model.bio)
    }
}

// ❌ Incorrect — @State is for view-owned value types, not passed-in objects
struct ProfileEditForm: View {
    @State var model: ProfileModel
}
```

---

## `@Entry` — Custom Environment Values (iOS 18+)

iOS 18 introduced the `@Entry` macro, which eliminates the `EnvironmentKey` boilerplate for custom environment values.

```swift
// ✅ iOS 18+: @Entry macro — no EnvironmentKey struct needed
extension EnvironmentValues {
    @Entry var seasonTheme: SeasonTheme = .lawn
}

// Inject at any ancestor
ContentView()
    .environment(\.seasonTheme, currentTheme)

// Read in descendants
@Environment(\.seasonTheme) private var theme

// ❌ iOS 17 boilerplate — still works but no longer necessary
struct SeasonThemeKey: EnvironmentKey {
    static let defaultValue: SeasonTheme = .lawn
}
extension EnvironmentValues {
    var seasonTheme: SeasonTheme {
        get { self[SeasonThemeKey.self] }
        set { self[SeasonThemeKey.self] = newValue }
    }
}
```

---

## Business Logic as Computed Properties

A View struct should hold `@State` for local UI, declare `@FetchRequest` for Core Data, and express business logic as **computed properties** — not methods called inside `body`, and not separate ViewModel files.

```swift
// ✅ Filtering logic as a computed property in the View.
// User-input matching uses localizedStandardContains — case- and
// diacritic-insensitive, the Finder-style behavior users expect.
// Not contains(), not localizedCaseInsensitiveContains().
private var filteredCustomers: [Customer] {
    let base = customers.filter { matchesFilter($0) }
    guard !searchText.isEmpty else { return base }
    return base.filter { $0.name.localizedStandardContains(searchText) }
}

// ❌ Separate @Observable class that duplicates FetchRequest state
@Observable final class CustomerListViewModel {
    var customers: [Customer] = []   // manual copy of @FetchRequest
    var searchText: String = ""      // should be @State in the View
}
```

### When a computed property grows: extract a pure function, not a ViewModel

The moment derived logic becomes worth unit-testing (multi-criteria filtering, sorting + grouping, form validation), move it to a **pure static function** on the model or a service enum. The view keeps a one-line computed property; the logic becomes trivially testable with plain inputs — no view instantiation, no new layer, no state duplication.

```swift
// ✅ Pure function owns the logic; the view just calls it
extension Customer {
    static func matching(_ customers: [Customer], search: String, filter: CustomerFilter) -> [Customer] {
        // combine filter + search + sort — all testable with plain arrays
    }
}

// View — one line, still no ViewModel
private var filteredCustomers: [Customer] {
    Customer.matching(Array(customers), search: searchText, filter: activeFilter)
}

// Test — no view, no store, no mocks
@Test func matching_appliesFilterBeforeSearch() {
    #expect(Customer.matching(fixtures, search: "al", filter: .active).count == 2)
}
```

This is the missing rung between "computed property in the view" and "service method with a context" (anti-patterns.md #11) — use it whenever the property's body outgrows a few lines or gains branching worth testing.

---

## Data-Flow Rules That Prevent Silent Bugs

- **`@Observable` classes driving UI must be `@MainActor`** (implicit if the module enables main-actor default isolation — see concurrency.md).
- **Never put `@AppStorage` inside an `@Observable` class** — even with `@ObservationIgnored` it does not publish changes, so views silently stop updating. Keep `@AppStorage` in views, or mirror the value manually.
- **Avoid `Binding(get:set:)` inside `body`** — it recreates the binding every render and defeats change detection. Use `@State` plus `.onChange(of:)` (always the two-parameter or zero-parameter variant).
- **Numeric input needs both halves:** `TextField("Price", value: $price, format: .number)` *and* `.keyboardType(.decimalPad)` — the modifier alone doesn't parse, the format alone doesn't constrain the keyboard.
- **Conform models to `Identifiable`** instead of scattering `id: \.someProperty` at every `ForEach`/`List` call site.
- **`@State` as a cache for expensive non-observable objects is legitimate** (e.g. a `CIContext` or formatter you don't want rebuilt per render) — the ban is on `@State` mirroring shared/observable data, not on caching.

---

## Unidirectional Data Flow Blueprint

```swift
// Service — @Observable, lives at app root
@Observable @MainActor final class OrderService {
    private(set) var orders: [Order] = []

    func refresh() async {
        orders = await APIClient.fetchOrders()
    }
}

// Root — owns the service instance
@main struct MyApp: App {
    @State private var orderService = OrderService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(orderService)
        }
    }
}

// View — reads from environment, no @StateObject
struct OrderListView: View {
    @Environment(OrderService.self) private var orderService

    var body: some View {
        List(orderService.orders) { order in
            OrderRow(order: order)
        }
        .task { await orderService.refresh() }
    }
}
```
