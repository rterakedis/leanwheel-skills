# Testability — Seed Data, Launch Arguments & UI Test Automation

> Updated: 2026-07-08 — iOS/iPadOS 18+ / Swift 6.2
> The app-side plumbing that makes automated testing cheap: one seed-scenario registry, a launch-argument contract, and a thin XCUITest smoke suite. Built in Epic 1, kept current every story — never retrofitted.

---

## Posture — the pyramid for rapid iteration

While the product is still shifting shape, invest where tests survive pivots:

1. **Unit tests on logic** (services, state machines, validation — see `testing.md`) — grow continuously; they survive UI rewrites.
2. **Seed scenarios + previews + `/design-verify`** — how you *look at* the app cheaply; no test code to maintain.
3. **XCUITest: smoke suite only** while iterating — app launches, main navigation works, one create-happy-path. Expand into flow coverage at epic boundaries via `/e2e-tests` (converting the stabilized manual test plan), not speculatively.

A big UI test suite over a UI you're about to redesign is negative-value work. Seeds are the opposite: they get *more* valuable with every pivot, because reaching any app state stays free.

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

(Core Data equivalent: `PersistenceController(inMemory:)` — same contract, same arguments.)

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

## XCUITest Smoke Suite — thin while iterating

The foundation story ships **one** `XCUITest` target with a launch helper and 2–4 smoke tests. That's the whole UI suite until the design stabilizes.

```swift
final class SmokeTests: XCTestCase {
    func launch(seed: String = "typical") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest", "--seed", seed]
        app.launch()
        return app
    }

    func testLaunch_showsSeededContent() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["trip-row-title"].firstMatch.waitForExistence(timeout: 5))
    }

    func testEmptyState_rendersOnFreshInstall() {
        let app = launch(seed: "empty")
        XCTAssertTrue(app.staticTexts["trip-empty-state"].waitForExistence(timeout: 5))
    }

    func testCreateTrip_happyPath() {
        let app = launch(seed: "empty")
        app.buttons["trip-add-button"].tap()
        app.textFields["trip-name-field"].typeText("Tokyo")
        app.buttons["trip-save-button"].tap()
        XCTAssertTrue(app.staticTexts["Tokyo"].waitForExistence(timeout: 5))
    }
}
```

Rules:
- **State comes from `--seed`, never from in-test tapping** — a test that taps through onboarding to reach its subject re-tests onboarding in every test and breaks whenever onboarding changes.
- `waitForExistence(timeout:)` over `sleep`; never assert on animation timing.
- Smoke tests run in the story/epic Build & Test Gate like any other test — a red smoke test blocks `done`.

❌ While the UI is still pivoting: per-screen UI test files, pixel/layout assertions in XCUITest (that's `/design-verify`'s job), UI tests for logic a unit test covers.

---

## Keeping It Current — the per-story contract

- A story that **adds or changes a persisted model entity** updates `SeedScenario` (at minimum `.typical` and `.edge`) in the same story. The compile-time break from `samples` makes skipping this hard — don't silence it with empty arrays.
- A story that **adds user-facing views** assigns accessibility identifiers as the views are written.
- New flows do **not** automatically get XCUITests mid-epic — they get manual Testing Plan entries, then `/e2e-tests` converts the stable ones at the epic boundary.
