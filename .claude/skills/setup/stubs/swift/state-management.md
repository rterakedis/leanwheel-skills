# State Management & Data Flow

> Updated: 2026-06-08 — iOS/iPadOS 19+
> iOS 18+ | Source of truth for observation, data flow, and property wrapper selection.

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
// ✅ Filtering logic as a computed property in the View
private var filteredCustomers: [Customer] {
    let base = customers.filter { matchesFilter($0) }
    guard !searchText.isEmpty else { return base }
    return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
}

// ❌ Separate @Observable class that duplicates FetchRequest state
@Observable final class CustomerListViewModel {
    var customers: [Customer] = []   // manual copy of @FetchRequest
    var searchText: String = ""      // should be @State in the View
}
```

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
