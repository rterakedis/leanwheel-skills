# Testability — Seed Data, Launch Arguments & UI Test Automation

> Updated: 2026-07-30 — iOS/iPadOS 18+ / Swift 6.2
> The app-side plumbing that makes automated testing cheap: one seed-scenario registry, a launch-argument contract, a deep-link route for every screen, and semantic identifiers. Built in Epic 1, kept current every story — never retrofitted.
> The host side that consumes all of this — `scripts/sim.sh`, the screenshot matrix, flows — is `simulator.md`.

---

## Posture — the pyramid for rapid iteration

While the product is still shifting shape, invest where tests survive pivots:

1. **Unit tests on logic** (services, state machines, validation — see `testing.md`) — grow continuously; they survive UI rewrites.
2. **Seeds + routes + `/design-verify`** — how you *look at* the app cheaply; no test code to maintain.
3. **Flows: grow by tier, not deferred to the epic boundary** — the 2–4-flow smoke suite (launches, main navigation, one create-happy-path), plus **one write-flow per screen once its data contract lands**. Detailed per-field assertions wait for the epic's manual test pass (`/e2e-tests` converts the stabilized plan). The tier ladder — and the failure mode it exists to prevent — lives in `simulator.md` (*Flows ▸ When to add one*).

A big *assertion-heavy* suite over a UI you're about to redesign is negative-value work — but identifier-driven flows couple to structure and semantics, not appearance, so re-theming/spacing/motion churn doesn't count against them (see `simulator.md`). Seeds and routes get *more* valuable with every pivot, because reaching any app state stays free.

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

The app honors four DEBUG-only launch arguments, parsed once at startup:

| Argument | Effect |
|---|---|
| `--seed <scenario>` | Apply the named `SeedScenario` at launch |
| `--route <name>` | Navigate to a route at startup, through the **same route table** `.onOpenURL` uses (see Deep-Link Routes below) |
| `--uitest` | Use an **in-memory store** (never touches real user data; hermetic, no cleanup) and disable animations |
| `--reset` | Wipe the persistent store before launch (manual-testing convenience) |

```swift
@main
struct TripApp: App {
    let container: ModelContainer
    @State private var router = Router()

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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
                .onOpenURL { router.handle($0) }      // production entry point
                .task { router.applyLaunchRoute() }   // DEBUG: --route, same table
        }
        .modelContainer(container)
    }
}
```

```swift
extension Router {
    /// DEBUG-only. Builds the same URL an external deep link would and hands it to the
    /// same `handle(_:)`. This is a delivery mechanism, not a second route table —
    /// see "Deep-Link Routes" for why unattended runs can't use the external one.
    func applyLaunchRoute() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--route"), args.indices.contains(i + 1) else { return }
        let raw = args[i + 1]
        guard let url = URL(string: raw.contains("://") ? raw : "trip://\(raw)") else { return }
        handle(url)
        #endif
    }
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

**The floor is never zero.** The same story that adds a screen ships its route **and one landmark identifier on the screen's root** (~2 lines) — that alone makes the screen dumpable and capturable by `sim.sh dump`/`shots`. "We'll add identifiers when a flow needs them" combined with "flows wait for stability" means a whole epic can ship with zero drivable surface; the flow tier ladder in `simulator.md` exists to prevent exactly that.

---

## Deep-Link Routes — every screen is reachable by name

Navigation for testing, screenshots, and flows is **always** by named route — never by tapping through the UI. The app registers one URL scheme and one route table:

```swift
// Info.plist (once): CFBundleURLTypes ▸ CFBundleURLSchemes ▸ "trip"
// Production code — NOT #if DEBUG. These are real links (widgets, notifications,
// shareable URLs); testing reuses them rather than adding a parallel mechanism.
.onOpenURL { url in router.handle(url) }
```

Route names are a stable contract, like scenario names: `trip://trips`, `trip://trip/new`, `trip://settings`. A story that **adds a screen adds its route**, in the same story.

### One route table, two deliveries

| Delivery | Used by | Attended? |
|---|---|---|
| `.onOpenURL` (external URL) | widgets, notifications, shareable links, `sim.sh open` | **yes** — see below |
| `--route <name>` launch argument | `sim.sh launch` / `shots` / `dump`, XCUITest flows | no |

**iOS 26 interposes an "Open in “<App>”?" / Cancel / Open system alert on any
custom-scheme URL opened from outside the app** — including `xcrun simctl openurl`
against an already-running, foregrounded app. Until a human taps *Open*, the URL never
reaches `.onOpenURL`. Unattended automation therefore cannot use external URL delivery
at all, and the failure is silent and total: the run continues, the screenshot captures
the alert sitting on top of the wrong screen, and nothing reports a dropped route. Hence
`--route`, handled in-process at startup.

This is **not** the `--screen` launch argument rejected earlier. `--screen` would have
been a second navigation vocabulary with its own switch statement. `--route` is a dozen
lines that build the same URL and call the same `handle(_:)`: identical route names,
identical handler, `.onOpenURL` still the production path. Only the delivery changes,
because on iOS 26 the external delivery is unavailable to a machine.

❌ A DEBUG-only parallel *route table*. ❌ Tapping through onboarding to reach a screen.
❌ `simctl openurl` in any unattended script.

---

## UI Tests — the first four are the smoke suite

The foundation story ships **one** XCUITest target, the shared `launch(seed:route:)` / `step(_:_:)` helpers, and 2–4 flows: app launches seeded, main navigation works, one empty state, one create-happy-path. That's the floor, not the ceiling — each screen adds one **write-flow** when its data-contract ACs land (Tier 2 in `simulator.md`'s ladder); detailed assertions wait for the manual test pass.

Full conventions — file layout, naming, the screenshot-per-step helper, and when a flow may be added — live in `simulator.md`. Two rules matter enough to repeat here:

- **State comes from `--seed` + a route, never from in-test tapping.** A test that taps through onboarding re-tests onboarding on every run and breaks whenever onboarding changes.
- Flows run in the story/epic Build & Test Gate like any other test — a red flow blocks `done`.

❌ While the UI is still pivoting: per-screen UI test files, pixel/layout assertions in XCUITest (that's `/design-verify`'s job), UI tests for logic a unit test covers.

---

## Keeping It Current — the per-story contract

- A story that **adds or changes a persisted model entity** updates `SeedScenario` (at minimum `.typical` and `.edge`) in the same story. The compile-time break from `samples` makes skipping this hard — don't silence it with empty arrays.
- A story that **adds user-facing views** assigns accessibility identifiers as the views are written, using the identifiers its Design Contract already names.
- A story that **adds a screen** adds that screen's deep-link route **and a landmark identifier on its root** in the same story — otherwise the screen is unreachable by `/design-verify`, undumpable, and invisible to every future flow.
- A story that **ships a screen's mutations** (its read/write ACs) adds one **write-flow** in the same story — even while layout is in flux. Detailed per-field flows still wait for the epic boundary; the tiering is in `simulator.md`.
