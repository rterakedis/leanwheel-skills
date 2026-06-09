# Concurrency & Safe Threading

> Updated: 2026-06-08 — iOS/iPadOS 19+
> iOS 18+ / Swift 6 | Async patterns, actor isolation, and UI thread safety.

---

## `.task` — The Default for View-Lifecycle Async

`.task` starts when the view appears and **automatically cancels when the view disappears**. This is the correct default for any async work tied to a view's presence on screen.

```swift
// ✅ Auto-cancelled on disappear
.task { await orderService.refresh() }

// ✅ Re-triggered on value change — replaces manual debounce
.task(id: searchText) {
    try? await Task.sleep(for: .milliseconds(400))
    await viewModel.search(searchText)
}

// ✅ Fire-and-forget after user action where cancellation is wrong
Button("Save") { Task { try? await save() } }

// ❌ Leaks if view disappears before task completes
.onAppear { Task { await loadData() } }

// ❌ Combine for something async/await handles natively
cancellable = publisher.sink { ... }
```

---

## `@MainActor` — UI Thread Safety

Any `@Observable` class that mutates properties observed by a view must annotate those mutations with `@MainActor`. Apply at the class level when all methods drive UI state.

SwiftUI `View` conformances are implicitly `@MainActor` — you don't need to annotate View structs themselves. However, `@Observable` service classes are not implicitly `@MainActor` and must be annotated explicitly.

```swift
// ✅ Class-level @MainActor — all property mutations on main thread
@Observable @MainActor final class AuthService {
    private(set) var isAuthenticated = false

    func signIn(credentials: Credentials) async throws {
        isAuthenticated = try await APIClient.authenticate(credentials)
    }
}

// ✅ Method-level — background work, then main-thread update
@Observable final class SyncEngine {
    @MainActor private(set) var lastSyncDate: Date?

    func sync() async {
        let result = await performBackgroundSync()   // background
        await MainActor.run { lastSyncDate = result } // main thread
    }
}
```

---

## `actor` — Protecting Mutable State Across Contexts

Use `actor` for service types whose state is accessed from multiple concurrency contexts. Replace any `DispatchQueue` used for thread-safety with an `actor`.

```swift
// ✅ actor with @MainActor output property
actor NetworkMonitor {
    @MainActor private(set) var isConnected = true

    func startMonitoring() {
        // actor-isolated internal state mutations are safe
    }
}

// ❌ Raw DispatchQueue — no Swift concurrency isolation
private let networkQueue = DispatchQueue(label: "net", qos: .utility)
```

---

## Parallel Work — `async let` vs `TaskGroup`

**`async let`** is the right choice for a small, fixed number of parallel tasks where you know the count at compile time.

**`TaskGroup`** is for a dynamic number of tasks (e.g., fetching N items from an array).

```swift
// ✅ async let — 2-3 known parallel fetches
func loadDashboard() async throws -> Dashboard {
    async let orders = fetchOrders()
    async let notifications = fetchNotifications()
    async let profile = fetchProfile()
    return try await Dashboard(orders: orders, notifications: notifications, profile: profile)
}

// ✅ TaskGroup — dynamic count, collect results
func loadAll(items: [Item]) async throws -> [ItemDetail] {
    try await withThrowingTaskGroup(of: ItemDetail.self) { group in
        for item in items {
            group.addTask { try await fetchDetail(for: item) }
        }
        var results: [ItemDetail] = []
        for try await detail in group { results.append(detail) }
        return results
    }
}

// ❌ Serial await — fetches one at a time when they could be parallel
let orders = try await fetchOrders()
let notifications = try await fetchNotifications()
```

---

## Swift 6 Strict Concurrency

With Swift 6 strict concurrency enabled (default in Xcode 16+), the compiler enforces actor isolation at compile time. Key implications:

- `@Observable` classes accessed from multiple isolation contexts require explicit `@MainActor` or `nonisolated` annotations.
- Closures capturing `self` in `Task {}` must be `@Sendable` — avoid capturing mutable state without isolation.
- Prefer structured concurrency (`.task`, `async let`, `TaskGroup`) over `Task { }` to get automatic cancellation and isolation inference.
- Test suites touching `@MainActor`-isolated types must be annotated `@MainActor` at the suite level.

```swift
// ✅ Swift 6 safe — crosses isolation boundary cleanly
.task {
    await orderService.refresh()
}

// ❌ May produce data race warning under Swift 6
Task {
    self.localState = await fetchSomething()  // captures mutable state without isolation
}
```

Swift 6.2 (released 2025) improved the approachability of strict concurrency by reducing false-positive warnings while maintaining the same guarantees. Most SwiftUI apps that follow the patterns in this document will compile cleanly under Swift 6.
