# Architecture & Project Structure

> Updated: 2026-06-08 — iOS/iPadOS 19+
> iOS 18+ | Project topology, feature isolation, and service layer conventions.

---

## Directory Topology — Feature-Based Over Type-Based

For apps spanning multiple epics, organize by **feature** (what the code does) rather than by **type** (what kind of file it is). Type-based structures (`/Models`, `/Views`, `/Services`) collapse under growth; feature-based structures isolate epics.

```
MyApp/
├── App/
│   ├── MyApp.swift              # @main entry, environment injection
│   └── AppEnvironment.swift     # Root @State service instances
│
├── Features/
│   ├── Orders/
│   │   ├── OrderListView.swift
│   │   ├── OrderDetailView.swift
│   │   └── OrderRow.swift
│   ├── Profile/
│   │   ├── ProfileView.swift
│   │   └── ProfileEditView.swift
│   └── Auth/
│       ├── SignInView.swift
│       └── AuthService.swift    # Feature-scoped service
│
├── Core/
│   ├── Networking/
│   │   ├── APIClient.swift      # actor
│   │   └── Endpoint.swift
│   ├── Storage/
│   │   ├── PersistenceController.swift
│   │   └── CacheStore.swift     # actor
│   └── Extensions/
│       └── Date+Formatting.swift
│
└── Shared/
    ├── Components/              # Reusable UI (buttons, cards, empty states)
    └── Models/                  # Value types shared across features
```

---

## Shared Core Isolation Rules

- `Core/` contains no SwiftUI imports — it is framework-agnostic business logic.
- `Core/Networking/APIClient` is an `actor`. It is never instantiated inside a View.
- `Core/Storage/PersistenceController` is a singleton with an `inMemory:` constructor for tests.
- Features import from `Core/` and `Shared/`. They do **not** import from sibling features.
- Cross-feature navigation is coordinated at the `App/` level or via `@Environment`-injected routing, not by one feature importing another.

---

## Service Layer Conventions

### When a Service Belongs in `Core/`

A service belongs in `Core/` when:
- It is used by more than one feature
- It wraps a system framework (StoreKit, CloudKit, CoreLocation, UserNotifications)
- It has no dependency on SwiftUI

### When a Service Belongs in `Features/`

A service belongs in the feature folder when:
- It is used exclusively by views in that feature
- It wraps feature-specific business logic (e.g., `CartService` for a shopping cart feature)

### Service Injection Pattern

App root creates all service instances as `@State` and injects them into the environment once. Features consume via `@Environment`. No service is ever instantiated inside a `View.body`.

```swift
// ✅ App/MyApp.swift — all services created once at root
@main struct MyApp: App {
    @State private var authService = AuthService()
    @State private var orderService = OrderService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .environment(orderService)
        }
    }
}

// ✅ Feature view — consumes from environment
struct OrderListView: View {
    @Environment(OrderService.self) private var orderService
}

// ❌ Never instantiate services inside a view
struct OrderListView: View {
    let orderService = OrderService()   // wrong — creates a new instance per render
}
```

---

## Navigation — Value-Based with Type-Safe Routing

Use `NavigationStack` with value-based navigation (`.navigationDestination(for:)`). For larger apps, centralize routing in an enum so all destinations are declared once.

```swift
// ✅ Simple value-based navigation
NavigationStack {
    OrderListView()
        .navigationDestination(for: Order.self) { order in
            OrderDetailView(order: order)
        }
}

// ✅ Type-safe enum routing for apps with many destinations
enum AppRoute: Hashable {
    case orderDetail(Order)
    case settings
    case search(String)
}

@Observable @MainActor final class Router {
    var path: [AppRoute] = []
}

// Root view wires up all destinations in one place
NavigationStack(path: $router.path) {
    OrderListView()
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .orderDetail(let order): OrderDetailView(order: order)
            case .settings: SettingsView()
            case .search(let query): SearchResultsView(query: query)
            }
        }
}
.environment(router)

// Any descendant pushes by appending to the path
@Environment(Router.self) private var router
Button("Open Detail") { router.path.append(.orderDetail(order)) }

// ❌ Deprecated — do not use NavigationView
NavigationView { ... }

// ❌ Inline destination closures for non-trivial cases
NavigationLink(destination: OrderDetailView(order: order)) { ... }
```
