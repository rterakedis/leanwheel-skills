# Testability — Seed Data, Launch Arguments & UI Test Automation

> Updated: 2026-07-30 — iOS/iPadOS 18+ / Swift 6.2
> The app-side plumbing that makes automated testing cheap: one seed-scenario registry, a launch-argument contract, a deep-link route for every screen, and semantic identifiers. Built in Epic 1, kept current every story — never retrofitted.
> The host side that consumes all of this — `scripts/sim.sh`, the screenshot matrix, flows — is `simulator.md`.

---

## Posture — the pyramid for rapid iteration

While the product is still shifting shape, invest where tests survive pivots:

1. **Unit tests on logic** (services, state machines, validation — see `testing.md`) — grow continuously; they survive UI rewrites.
2. **Seeds + routes + `/design-verify`** — how you *look at* the app cheaply; no test code to maintain.
3. **Flows: 2–4 while iterating** — app launches, main navigation works, one create-happy-path. Expand at epic boundaries via `/e2e-tests` (converting the stabilized manual test plan), never speculatively. Definition and conventions in `simulator.md`.

A big UI test suite over a UI you're about to redesign is negative-value work. Seeds and routes are the opposite: they get *more* valuable with every pivot, because reaching any app state stays free.

---

## Seed Scenario Registry — one registry, four consumers

Define a single DEBUG-only registry of named data scenarios next to the domain model. Every way of looking at the app consumes the same registry: **previews**, **simulator runs**, **XCUITests**, and **`/design-verify` screenshots**.

```swift
// Seeding/SeedScenario.swift — entire file wrapped in #if DEBUG
#if DEBUG
import SwiftData

enum SeedScenario: String, CaseIterable {
    case empty      // fresh install, nothing created — exercises empty states
    case firstRun   // minimal: 1 of the core entity, onboarding just completed
    case typical    // a few of everything — the default demo/test state
    case heavy      // hundreds of rows — scrolling, pagination, perf
    case edge       // hostile data: 300-char names, emoji, past/future dates, 0 and negative amounts

    @MainActor
    func apply(to context: ModelContext) throws {
        switch self {
        case .empty: break
        case .typical:
            for sample in Trip.samples { context.insert(sample) }
            for sample in Expense.samples { context.insert(sample) }
        // ...
        }
        try context.save()
    }
}
#endif
```

Rules:
- **Scenario names are a stable contract** — tests, previews, and the story files' Testing Plans refer to them by name. Add scenarios; rename rarely.
- **Sample data lives with the model** (`extension Trip { static let samples: [Trip] = … }`) so a model change breaks seeds *at compile time* — the loudest possible reminder to update them.
- `.edge` is not optional decoration — most field-layout and truncation bugs live there.

❌ Hand-crafted per-test fixtures scattered across test files, ad-hoc "tap around to set up state" in UI tests, or a `PreviewData.swift` that drifts from what tests use — one registry, or the copies rot.

---

## Launch Argument Contract

The app honors three DEBUG-only launch arguments, parsed once at startup:

| Argument | Effect |
|---|---|
| `--seed <scenario>` | Apply the named `SeedScenario` at launch |
| `--uitest` | Use an **in-memory store** (never touches real user data; hermetic, no cleanup) and disable animations |
| `--reset` | Wipe the persistent store before launch (manual-testing convenience) |

```swift
@main
struct TripApp: App {
    let container: ModelContainer

    init() {
        var inMemory = false
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        inMemory = args.contains("--uitest")
        #endif
        container = try! ModelContainer(
            for: Trip.self, Expense.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
        #if DEBUG
        if let i = args.firstIndex(of: "--seed"), args.indices.contains(i + 1),
           let scenario = SeedScenario(rawValue: args[i + 1]) {
            try? scenario.apply(to: ModelContext(container))
        }
        if args.contains("--uitest") { UIView.setAnimationsEnabled(false) }
        #endif
    }
    var body: some Scene { WindowGroup { ContentView() }.modelContainer(container) }
}
```

### Core Data — same contract, three extra hazards

```swift
// Persistence.swift
struct PersistenceController {
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // CloudKit is attached ONLY on a real, non-seeded run. A seeded or --uitest
        // launch against NSPersistentCloudKitContainer pushes fixture rows into the
        // developer's real private database — the single worst failure mode here,
        // and it is silent until junk shows up on their devices.
        #if !targetEnvironment(simulator)
        container = inMemory ? NSPersistentContainer(name: "Model")
                             : NSPersistentCloudKitContainer(name: "Model")
        #else
        container = NSPersistentContainer(name: "Model")
        #endif

        if inMemory {
            let description = container.persistentStoreDescriptions.first!
            description.url = URL(fileURLWithPath: "/dev/null")  // SQLite semantics, nothing on disk
            description.cloudKitContainerOptions = nil           // belt and braces
        }
        container.loadPersistentStores { _, error in
            if let error { fatalError("store load failed: \(error)") }
        }
        // Seeds are written on a background context; the view context must see them.
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
```

```swift
// Seeding on a background context — never block launch on the main queue.
extension SeedScenario {
    func apply(to container: NSPersistentContainer) async throws {
        try await container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            switch self {
            case .empty: return
            case .typical:
                Trip.samples(in: context); Expense.samples(in: context)
            // ...
            }
            if context.hasChanges { try context.save() }
        }
    }
}
```

Three things that bite on Core Data specifically:
- **CloudKit must be off for any seeded or `--uitest` run** (above). Non-negotiable.
- **`/dev/null` beats `NSInMemoryStoreType`** — it keeps real SQLite semantics (constraints, batch requests, `NSFetchedResultsController` behavior), so tests fail the way production would.
- **Sample data takes a `context`**, unlike SwiftData's context-free `static let samples`. Keep them as `static func samples(in:)` on the entity so a model change still breaks seeds at compile time.

- **Manual testing:** duplicate the Run scheme per scenario, or add a DEBUG-only developer menu (shake gesture / hidden settings row) that applies a scenario at runtime.
- **Previews:** reuse the registry via `PreviewModifier` (iOS 18+) — seeded, in-memory, shared across previews:

```swift
#if DEBUG
struct SeededPreview: PreviewModifier {
    static func makeSharedContext() async throws -> ModelContainer {
        let c = try ModelContainer(for: Trip.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        try SeedScenario.typical.apply(to: ModelContext(c))
        return c
    }
    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}
#Preview(traits: .modifier(SeededPreview())) { TripListView() }
#endif
```

❌ Seed code compiled into Release builds; seeding by shipping a pre-filled store file; tests that mutate the developer's real simulator data.

---

## Accessibility Identifiers — assigned at view creation, not backfilled

Every interactive element and every dynamic list row gets a semantic `.accessibilityIdentifier` **in the same story that creates the view**. Backfilling identifiers later means re-touching every screen — the classic retrofit tax.

```swift
// ✅ Stable, semantic, data-qualified for rows
Button("Add Trip") { … }.accessibilityIdentifier("trip-add-button")
List(trips) { trip in
    TripRow(trip).accessibilityIdentifier("trip-row-\(trip.id)")
}

// ❌ Locating by visible label text — breaks on copy changes and localization
app.buttons["Add Trip"].tap()
```

Convention: `{feature}-{element}-{role}`, kebab-case. These double as the semantic locators `/e2e-tests` requires.

---

## Deep-Link Routes — every screen is reachable by name

Navigation for testing, screenshots, and flows is **always** by deep link — never by tapping through the UI. The app registers one URL scheme and routes to any screen:

```swift
// Info.plist (once): CFBundleURLTypes ▸ CFBundleURLSchemes ▸ "trip"
// Production code — NOT #if DEBUG. These are real links (widgets, notifications,
// shareable URLs); testing reuses them rather than adding a parallel mechanism.
.onOpenURL { url in router.handle(url) }
```

Route names are a stable contract, like scenario names: `trip://trips`, `trip://trip/new`, `trip://settings`. A story that **adds a screen adds its route**, in the same story.

Why this and not a `--screen` launch argument: a route works on the *already running* app, so a 24-capture screenshot matrix costs one launch instead of 24 relaunches. `XCUIApplication.openURL(_:)` (iOS 16.4+) lets flows use the same routes, so there is exactly one navigation mechanism everywhere.

❌ A DEBUG-only parallel navigation path. ❌ Tapping through onboarding to reach a screen.

---

## UI Tests — the first four are the smoke suite

The foundation story ships **one** XCUITest target, the shared `launch(seed:route:)` / `step(_:_:)` helpers, and 2–4 flows: app launches seeded, main navigation works, one empty state, one create-happy-path. That's the whole UI suite until the design stabilizes.

Full conventions — file layout, naming, the screenshot-per-step helper, and when a flow may be added — live in `simulator.md`. Two rules matter enough to repeat here:

- **State comes from `--seed` + a route, never from in-test tapping.** A test that taps through onboarding re-tests onboarding on every run and breaks whenever onboarding changes.
- Flows run in the story/epic Build & Test Gate like any other test — a red flow blocks `done`.

❌ While the UI is still pivoting: per-screen UI test files, pixel/layout assertions in XCUITest (that's `/design-verify`'s job), UI tests for logic a unit test covers.

---

## Keeping It Current — the per-story contract

- A story that **adds or changes a persisted model entity** updates `SeedScenario` (at minimum `.typical` and `.edge`) in the same story. The compile-time break from `samples` makes skipping this hard — don't silence it with empty arrays.
- A story that **adds user-facing views** assigns accessibility identifiers as the views are written, using the identifiers its Design Contract already names.
- A story that **adds a screen** adds that screen's deep-link route in the same story — otherwise the screen is unreachable by `/design-verify` and by every future flow.
- New screens do **not** automatically get flows mid-epic — they get manual Testing Plan entries, then `/e2e-tests` converts the stable ones at the epic boundary.
