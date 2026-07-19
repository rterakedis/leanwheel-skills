# Concurrency & Safe Threading

> Updated: 2026-07-19 — iOS 18+ / Swift 6.2
> Async patterns, actor isolation, and UI thread safety. Concurrency rules are keyed to the **Swift language version**, not the iOS version.

---

## `.task` — The Default for View-Lifecycle Async

`.task` starts when the view appears and **automatically cancels when the view disappears** — but cancellation is cooperative (see Cancellation below). This is the correct default for any async work tied to a view's presence on screen.

```swift
// ✅ Auto-cancelled on disappear
.task { await orderService.refresh() }

// ✅ Re-triggered on value change — replaces manual debounce
.task(id: searchText) {
    try? await Task.sleep(for: .milliseconds(400))
    await search(searchText)
}

// ✅ Fire-and-forget after user action — handle the error inside the closure
Button("Save") {
    Task {
        do { try await save() }
        catch { saveError = error }   // surface to @State — never try? here
    }
}

// ❌ Leaks if view disappears before task completes
.onAppear { Task { await loadData() } }

// ❌ Swallowed error — a thrown error inside Task { } is silently lost
Button("Save") { Task { try? await save() } }
```

---

## `@MainActor` — UI Thread Safety

Any `@Observable` class that mutates properties observed by a view must run those mutations on the main actor. Apply `@MainActor` at the class level when all methods drive UI state.

SwiftUI `View` conformances are implicitly `@MainActor`. `@Observable` service classes need the annotation **unless the module has main-actor default isolation enabled** (see *Approachable Concurrency* below) — check the build setting before flagging a "missing" annotation.

```swift
// ✅ Class-level @MainActor — all property mutations on main thread
@Observable @MainActor final class AuthService {
    private(set) var isAuthenticated = false

    func signIn(credentials: Credentials) async throws {
        isAuthenticated = try await APIClient.authenticate(credentials)
    }
}
```

`await MainActor.run { }` is almost never needed: if the surrounding code is already main-actor-isolated it is a no-op, and if you are hopping back from background work the function should simply be `@MainActor` (or the work moved to `@concurrent`, below).

---

## Offloading CPU Work — `@concurrent` (Swift 6.2)

Since Swift 6.2, a `nonisolated` async function **runs on the caller's actor** — plain `async` no longer implies background execution. To genuinely move heavy synchronous work (parsing, image processing, crypto) off the main actor, mark it `@concurrent`:

```swift
// ✅ @concurrent — runs on the global executor, result hops back automatically
@Observable @MainActor final class SyncEngine {
    private(set) var lastSyncDate: Date?

    func sync() async {
        lastSyncDate = await Self.performSync()   // no MainActor.run needed
    }

    @concurrent nonisolated static func performSync() async -> Date { ... }
}

// ❌ Stale pattern — manual hop back to the main actor
let result = await performBackgroundSync()
await MainActor.run { lastSyncDate = result }

// ❌ Task.detached — sheds actor context AND priority; almost never what you want.
// Use @concurrent for CPU offload, TaskGroup for parallel work.
Task.detached { await heavyWork() }
```

---

## `actor` — Protecting Mutable State Across Contexts

Use `actor` for service types whose state is accessed from multiple concurrency contexts. Replace any `DispatchQueue` used for thread-safety with an `actor`.

### Reentrancy — every `await` invalidates your assumptions

Actors are **reentrant**: while one method is suspended at an `await`, other calls can run and mutate state. Check-then-act across an `await` is the single most common AI-generated concurrency bug.

```swift
// ❌ Race + crash: another caller may have mutated `cache` during the await,
// and the force-unwrap assumes state that may no longer hold
actor ImageCache {
    private var cache: [URL: Image] = [:]
    func image(for url: URL) async throws -> Image {
        if cache[url] == nil {
            cache[url] = try await downloadImage(url)
        }
        return cache[url]!
    }
}

// ✅ Capture into a local before/after the await; re-check state after resuming
actor ImageCache {
    private var cache: [URL: Image] = [:]
    func image(for url: URL) async throws -> Image {
        if let cached = cache[url] { return cached }
        let image = try await downloadImage(url)
        cache[url] = image        // last-writer-wins is acceptable for a cache
        return image
    }
}
```

Rule: after **every** `await` inside an actor, re-read any state you depend on — never assume it survived the suspension.

---

## Parallel Work — `async let` vs `TaskGroup`

**`async let`** for a small, fixed number of parallel tasks known at compile time. **`TaskGroup`** for a dynamic number.

```swift
// ✅ async let — 2-3 known parallel fetches
async let orders = fetchOrders()
async let profile = fetchProfile()
return try await Dashboard(orders: orders, profile: profile)

// ✅ TaskGroup — dynamic count, collect results
try await withThrowingTaskGroup(of: ItemDetail.self) { group in
    for item in items { group.addTask { try await fetchDetail(for: item) } }
    var results: [ItemDetail] = []
    for try await detail in group { results.append(detail) }
    return results
}

// ❌ Serial await — fetches one at a time when they could be parallel
let orders = try await fetchOrders()
let notifications = try await fetchNotifications()
```

---

## Cancellation Is Cooperative

`task.cancel()` (and `.task`'s auto-cancel) only **sets a flag** — the task body must observe it. A CPU-bound loop with no `await` and no check never cancels.

```swift
// ✅ Long loops check for cancellation explicitly
for row in hugeDataset {
    try Task.checkCancellation()      // throws CancellationError if cancelled
    process(row)
}

// ✅ CancellationError is a lifecycle event, not a failure — never alert/retry on it
do { items = try await loadItems() }
catch is CancellationError { }        // view went away; do nothing
catch { loadError = error }
```

---

## Bridging Legacy Callbacks — Continuations & AsyncStream

Combine is banned in new code (see anti-patterns.md); these are the replacements for callback/delegate APIs.

```swift
// ✅ One-shot callback → continuation. MUST resume exactly once
// (zero resumes = permanent hang, two = crash)
func currentLocation() async throws -> CLLocation {
    try await withCheckedThrowingContinuation { continuation in
        locationManager.requestLocation { result in
            continuation.resume(with: result)
        }
    }
}

// ✅ Repeating events → AsyncStream via makeStream (not the closure initializer),
// with a bounded buffer
let (stream, continuation) = AsyncStream.makeStream(of: Reading.self,
                                                    bufferingPolicy: .bufferingNewest(10))
```

`@unchecked Sendable` is **not a fix** — it silences the diagnostic without removing the race. It is legitimate only for lock-protected or immutable types; otherwise use an `actor`, a value type, or `sending`.

---

## Swift 6.2 Strict Concurrency — What Changed

Swift 6.2 is a **mental-model shift**, not just fewer warnings:

- **Approachable concurrency / main-actor default isolation** (opt-in, per module): most declarations behave as `@MainActor` unless opted out — you stop writing the annotation everywhere. Calls into other modules (networking, etc.) still run off the main actor. Check whether the project enables this before adding/flagging `@MainActor` annotations.
- **`nonisolated` async runs on the caller's actor** — plain async helpers no longer hop to a background thread, which removes a whole class of "sending 'x' risks causing data races" diagnostics. Use `@concurrent` when you *want* off-actor execution.
- **Isolated conformances**: `extension Foo: @MainActor SomeProtocol { }` lets a main-actor type satisfy a nonisolated protocol using its main-actor state — the canonical fix for "conformance crosses actor boundary" errors.
- **`Task {}` inherits the caller's isolation** — capturing `self` from a `@MainActor` context into a `Task` is safe and needs no `@Sendable` gymnastics.

### Fix ladder for "Sending 'x' risks causing data races"

Work top-down; each step is less preferable than the one above it:

1. Restructure so region-based isolation proves safety (often: build the value locally, send it once).
2. Mark the parameter `sending`.
3. Make the type `Sendable` (value type, or actor).
4. `nonisolated(nonsending)` on the async function so it stays on the caller's actor.
5. `@unchecked Sendable` — last resort, only with a real lock/immutability justification in a comment.

Test suites touching `@MainActor`-isolated types must be annotated `@MainActor` at the suite level (see testing.md).
