# Testing Conventions

> Updated: 2026-07-19 — iOS 18+ / Swift 6.2
> Swift Testing framework, assertion discipline, async testing, Core Data test setup, and concurrency-safe tests.

---

## Swift Testing — Required for All New Tests

Use `import Testing` for all new test files. `import XCTest` is legacy — do not add new XCTest classes.

```swift
// ✅ Modern
import Testing

@Suite("OrderService")
struct OrderServiceTests {

    @Test func createOrder_storesAllFields() throws {
        let order = Order(id: "123", total: 49.99, status: .pending)
        #expect(order.id == "123")
        #expect(order.total == 49.99)
        #expect(order.status == .pending)
    }

    @Test(arguments: [OrderStatus.pending, .processing, .shipped])
    func orderStatus_isTransitionable(from status: OrderStatus) {
        #expect(status.canTransition(to: .cancelled))
    }
}

// ❌ Legacy
import XCTest
class OrderServiceTests: XCTestCase {
    func testCreateOrder() {
        XCTAssertEqual(order.id, "123")
    }
}
```

Structure rules:
- Use a `struct` (class only when you need `deinit` or subclassing); `init()`/`deinit` replace `setUp`/`tearDown`.
- `@Suite` is only needed to attach a display name or traits — any type containing `@Test` is already a suite. Don't add a bare `@Suite` with no arguments.
- Parameterized tests with **two** argument collections form a Cartesian product (every combination). For pairwise cases, pass `zip(inputs, expected)`.
- Tag cross-cutting groups: `extension Tag { @Tag static var edgeCase: Self }` then `@Test(.tags(.edgeCase))`. Record regression provenance with `.bug(id:)`.

---

## Assertions — `#require` vs `#expect`

`#require` is for **preconditions**: it unwraps optionals and stops the test immediately on failure, so later assertions don't cascade-fail on garbage. `#expect` is for the **actual assertions** — the test keeps running so you see every failure. A test that reaches no `#expect`/`#require` at all silently passes — make sure every path asserts something.

```swift
@Test func loadOrder_parsesAllFields() async throws {
    // ✅ Precondition — unwraps and aborts early if missing
    let order = try #require(await store.order(id: "123"))

    // ✅ Real assertions — all evaluated even if one fails
    #expect(order.total == 49.99)
    #expect(order.isArchived == false)   // never #expect(!order.isArchived) — the
                                          // `!` defeats the macro's failure message
}

// ✅ Throwing: always name the specific error — never Error.self
#expect(throws: OrderError.notFound) { try store.remove(id: "missing") }

// ✅ Assert something does NOT throw
#expect(throws: Never.self) { try store.validate(order) }

// ✅ Need the thrown error? #expect(throws:) returns it (Swift 6.1+)
let error = #expect(throws: ValidationError.self) { try store.validate(bad) }
#expect(error?.field == "email")

// ✅ Inside do/catch, fail with Issue.record — never a bare comment
do { try risky() } catch { Issue.record("unexpected error: \(error)") }
```

---

## Async Testing — `confirmation`, Time Limits, Serialization

```swift
// ✅ Assert async work happened N times — the work must complete before the
// closure returns (make the method async or return its Task; completion-handler
// code that outlives the closure fails the confirmation)
@Test func sync_notifiesEachRecord() async {
    await confirmation(expectedCount: 3) { confirmed in
        let engine = SyncEngine(onRecord: { _ in confirmed() })
        await engine.sync(records: threeRecords)
    }
}

// ✅ Ranges work too: 5...10, 5..., and expectedCount: 0 means "never happens"

// ✅ Time limit — .minutes only; .seconds is NOT an accepted TimeLimitTrait
@Test(.timeLimit(.minutes(1))) func slowImport() async throws { ... }
```

`.serialized` only affects **parameterized tests** (or applies to a whole suite) — putting it on a single plain `@Test` does nothing.

---

## Dependency Injection — No Live Networking or Shared Defaults in Tests

Hidden dependencies (`URLSession.shared`, `UserDefaults.standard`) make tests flaky and order-dependent. Expose them as injected parameters with production defaults, protocol-wrapped so tests can substitute a mock.

```swift
// ✅ Production code: injectable with a default — call sites don't change
protocol URLSessionProtocol { func data(from url: URL) async throws -> (Data, URLResponse) }
extension URLSession: URLSessionProtocol {}

struct WeatherClient {
    var session: URLSessionProtocol = URLSession.shared
    func forecast() async throws -> Forecast { ... }
}

// ✅ Test: mock session, zero network
struct MockSession: URLSessionProtocol {
    let stubbed: Data
    func data(from url: URL) async throws -> (Data, URLResponse) { (stubbed, HTTPURLResponse()) }
}

// ✅ UserDefaults: per-test suite, cleaned up in deinit or defer
let defaults = try #require(UserDefaults(suiteName: #function))
defer { defaults.removePersistentDomain(forName: #function) }
```

---

## Core Data Tests — Always In-Memory

Never use the default persistent store in tests. Always create a `PersistenceController(inMemory: true)` instance. This is faster, isolated per test, and requires no cleanup.

```swift
// ✅ In-memory controller for every test
@Suite("CustomerService")
struct CustomerServiceTests {
    let controller = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { controller.container.viewContext }

    @Test func createCustomer_persistsToStore() throws {
        let service = CustomerService(context: context)
        let customer = try service.create(name: "Alice", email: "alice@example.com")
        #expect(customer.name == "Alice")
        #expect(customer.email == "alice@example.com")
    }
}

// ❌ Real persistent store — leaves state between tests, slow
let controller = PersistenceController.shared
```

### Asserting deletion — never check `isDeleted` after a save

`NSManagedObject.isDeleted` is `true` **only** in the window between `context.delete(obj)` and the next `context.save()`. After the save the object is evicted from the context: `isDeleted` reverts to `false` and `managedObjectContext` becomes `nil`. A test that deletes (or calls a service that saves internally) and then asserts `isDeleted == true` fails even though the delete was correct — a common source of phantom bug hunts.

```swift
// ❌ Wrong — isDeleted is false again after save()
service.delete(order, context: context)   // saves internally
#expect(order.isDeleted == true)           // FAILS despite a correct delete

// ✅ Re-fetch (best — proves the store state), or assert eviction from the context
#expect(try context.count(for: Order.fetchRequest()) == 0)
#expect(order.managedObjectContext == nil)
```

---

## Testing `@MainActor`-Isolated Types

When testing `@Observable` classes or functions annotated with `@MainActor`, annotate the entire test struct with `@MainActor`. Without it, Swift Testing runs tests on a non-main thread, causing deadlocks when accessing `viewContext`.

```swift
// ✅ @MainActor on the suite — all tests run on main actor
@Suite("AuthService")
@MainActor
struct AuthServiceTests {

    @Test func signIn_setsAuthenticated() async throws {
        let service = AuthService()
        try await service.signIn(credentials: .mock)
        #expect(service.isAuthenticated == true)
    }
}

// ✅ Suites using only newBackgroundContext() with context.perform { }
// do NOT need @MainActor
@Suite("BackgroundSyncService")
struct BackgroundSyncServiceTests {
    @Test func sync_completesWithoutError() async throws { ... }
}
```

---

## Swift Testing Attachments (Swift 6.2+)

Swift 6.2 added **attachments** for enriching test output with diagnostic data — useful for debugging failures in CI.

```swift
// ✅ Attach data to a test for inspection on failure — note the .record call;
// a bare Attachment(...) initializer records nothing
@Test func exportGenerate_producesValidPDF() async throws {
    let data = try await ExportService.generatePDF(for: order)

    try #require(data.count > 0)
    Attachment.record(data, named: "generated-output.pdf")

    #expect(data.isPDF)
}
```

`String`, `Data`, and `Encodable` values attach directly; image attachments require Swift 6.3+.

---

## What to Test

Test **service and business logic** — not SwiftUI rendering. Views are not unit-testable in isolation; their correctness is verified by running the app.

**Test these:**
- Service methods (create, update, delete, fetch)
- Computed properties with non-trivial logic
- Actor state transitions
- Validation functions and business rules
- Status progression logic (state machines)

**Do not write unit tests for:**
- View `body` layout
- Navigation stack state
- Core Data `@FetchRequest` results (integration concern; verify in Simulator)
- Animation timing
