# Testing Conventions

> Updated: 2026-06-14 — iOS/iPadOS 19+
> iOS 18+ / Swift 6.2 | Swift Testing framework, Core Data test setup, and concurrency-safe tests.

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
// ✅ Attach data to a test for inspection on failure
@Test func exportGenerate_producesValidPDF() async throws {
    let data = try await ExportService.generatePDF(for: order)
    
    // Attachment is captured in the test report on failure
    try #require(data.count > 0)
    Attachment(data, named: "generated-output.pdf")
    
    #expect(data.isPDF)
}
```

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
