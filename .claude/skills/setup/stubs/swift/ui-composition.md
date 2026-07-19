# UI Composition & Layout Rules

> Updated: 2026-07-19 — iOS 18+ (iOS 26 features flagged)
> Preventing massive views, subview extraction, layout decisions, HIG conventions, and new container APIs.

---

## The 50-Line Rule for View Body

If `var body: some View` exceeds ~50 lines, it must be decomposed. This is not a style preference — large bodies create re-render surface area and make conditional logic harder to audit.

Decomposition priority order:
1. Extract to a private `struct` sub-view (preferred — a struct is a real identity boundary, so its `body` only re-evaluates when its own inputs change)
2. Extract to a separate file in the same feature folder (when the component is reused or complex)
3. A private computed property returning `some View` — acceptable only for tiny static fragments. A computed property (or `@ViewBuilder` method) is **not** an identity boundary: it inlines into the parent's `body`, so the whole parent still re-evaluates as one unit. It organizes code; it does not scope invalidation.

```swift
// ✅ Struct sub-views — each is its own invalidation scope
struct OrderListView: View {
    var body: some View {
        VStack {
            OrderListHeader(count: orders.count)
            OrderList(orders: orders)
            OrderListFooter()
        }
    }
}

private struct OrderList: View {
    let orders: [Order]
    var body: some View {
        List(orders) { OrderRow(order: $0) }
    }
}

// ✅ Sub-view owning its own @State
private struct ExpandableOrderRow: View {
    let order: Order
    @State private var isExpanded = false

    var body: some View { ... }
}

// ⚠️ Computed property — fine for a static caption; wrong for anything that
// renders data, because it re-evaluates with every parent body pass
private var footerCaption: some View {
    Text("Prices include tax").font(.footnote)
}
```

This is layout decomposition only — logic still lives in the view or a service, never a per-view ViewModel (see anti-patterns.md #1).

---

## File-Level Decomposition — Targets & Techniques

The 50-line body rule keeps one `body` readable; this rule keeps the whole *file* maintainable for humans **and AI agents**. An agent editing one button in a 600-line sheet must load and reason over unrelated status logic, permission gates, and sub-view layout — every edit risks collateral damage. Small, single-responsibility files are the cheapest win for AI-assisted maintainability.

**Targets — triggers to evaluate, not hard limits:**

| File kind | Comfortable | Evaluate decomposition | Treat as a defect |
|---|---|---|---|
| SwiftUI view / sheet | ≤ 200 lines | ~300 lines | > 400 lines |
| Service / model / manager | ≤ 300 lines | ~400 lines | > 500 lines |

Line count is a signal to **look**, not a mandate to **cut**. A 280-line view with one cohesive responsibility can stay; a 180-line view doing three unrelated jobs should split. **Cohesion decides the cut — line count only triggers the review.** Never scatter one logical unit across files just to hit a number; that is as harmful as a god-file.

Two techniques, both Apple-blessed, neither introduces a ViewModel or any new architectural layer:

### 1. `extension` across files — for type *members* (methods, actions, helpers)

When a view's *logic* is the bloat — action handlers, status transitions, permission gates — split those members into `extension` files grouped by responsibility. Same type, no new type.

```
Features/Schedule/Sheets/
  JobDetailSheet.swift               ← struct + body composition only
  JobDetailSheet+StatusActions.swift ← advanceStatus / doAdvanceStatus
  JobDetailSheet+MileageGate.swift   ← permission check + @State + sheet triggers
```

```swift
// JobDetailSheet+StatusActions.swift
extension JobDetailSheet {
    func advanceStatus(to status: JobStatus) { ... }
    func doAdvanceStatus(to status: JobStatus) { ... }
}
```

Naming: `TypeName+Role.swift`, where `Role` names the one responsibility (`+StatusActions`, `+MileageGate`, `+Subviews`).

### 2. Named sub-view structs — for *layout* (cohesive sections of `body`)

When a cohesive section of `body` is the bloat, extract it to its own `private struct` (own file when reused or complex). Zero overhead — SwiftUI already diffs sub-views efficiently.

```
JobDetailJobHeader.swift   ← customer name, date, notes (sub-view struct)
JobStatusButtons.swift     ← En Route / In Progress / Complete buttons
```

Sub-views receive **only what they display** via `let` or `@Binding`, and report actions **up** via closures:

```swift
private struct JobStatusButtons: View {
    let status: JobStatus
    let onAdvance: (JobStatus) -> Void   // callback up — not a service down
    var body: some View { ... }
}
```

### The hard boundary: sub-view vs ViewModel

A sub-view struct holds **only display data and binding refs** — never service calls, Core Data contexts, or `@FetchRequest`. The moment a sub-view fetches or computes from raw data, it has become a ViewModel, which this project does not use. Keep data access in the parent view; pass results down as plain values, pass actions up as closures. (See anti-patterns.md.)

---

## `List` vs `ScrollView` + Lazy Stack

| Scenario | Use |
|---|---|
| Homogeneous rows with swipe actions, reorder, or section headers | `List` |
| Mixed-content feed, card grid, or custom spacing between items | `ScrollView` + `LazyVStack` |
| Fixed small number of items (under ~20, no scroll needed) | `VStack` |
| Grid layout | `ScrollView` + `LazyVGrid` |

`List` provides automatic row recycling, swipe-to-delete, edit mode, and accessibility. Prefer it for tabular data. Do not wrap `List` inside `ScrollView` — they conflict.

```swift
// ✅ List for rows with swipe actions
List(orders) { order in
    OrderRow(order: order)
        .swipeActions { Button("Delete", role: .destructive) { delete(order) } }
}

// ✅ LazyVStack for a feed with mixed content types
ScrollView {
    LazyVStack(spacing: 16) {
        ForEach(feedItems) { item in
            FeedCard(item: item)
        }
    }
    .padding(.horizontal)
}

// ❌ VStack for a potentially unbounded list — loads everything at once
ScrollView {
    VStack {
        ForEach(orders) { OrderRow(order: $0) }
    }
}
```

---

## ScrollView — New APIs (iOS 18+)

iOS 18 added scroll lifecycle and visibility APIs that replace manual offset detection hacks.

```swift
// ✅ onScrollPhaseChange — react to scroll state transitions
.onScrollPhaseChange { oldPhase, newPhase in
    withAnimation {
        toolbarHidden = newPhase != .idle
    }
}
// Phases: .idle, .tracking, .interacting, .decelerating, .animating

// ✅ onScrollTargetVisibilityChange — pagination without a sentinel view
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ItemRow(item)
        }
    }
    .scrollTargetLayout()
}
.onScrollTargetVisibilityChange(idType: Item.ID.self) { visibleIDs in
    if let last = visibleIDs.last, last == items.last?.id {
        loadNextPage()
    }
}

// ✅ onScrollGeometryChange — track scroll offset for parallax/sticky headers
.onScrollGeometryChange(for: CGFloat.self) { geo in
    geo.contentOffset.y
} action: { oldOffset, newOffset in
    headerOffset = newOffset
}

// ❌ Old hack — invisible sentinel view at the bottom of a list
struct BottomDetector: View {
    var onAppear: () -> Void
    var body: some View {
        Color.clear.onAppear { onAppear() }
    }
}
```

---

## TabView — New `Tab` Wrapper (iOS 18+)

iOS 18 replaced direct content placement in `TabView` with explicit `Tab` wrappers. The `.sidebarAdaptable` style automatically converts the tab bar to a sidebar on iPad and Mac Catalyst.

```swift
// ✅ iOS 18+: Tab wrapper with sidebar adaptation
TabView(selection: $selectedTab) {
    Tab("Schedule", systemImage: "calendar", value: "schedule") {
        ScheduleView()
    }
    Tab("Customers", systemImage: "person.2", value: "customers") {
        CustomersView()
    }
    Tab("Search", systemImage: "magnifyingglass", value: "search") {
        SearchView()
    }
    .role(.search)   // Search tab gets special placement
}
.tabViewStyle(.sidebarAdaptable)        // sidebar on iPad, tab bar on iPhone

// ❌ Old pattern — works but misses sidebar adaptation on iPad
TabView {
    ScheduleView().tabItem { Label("Schedule", systemImage: "calendar") }
    CustomersView().tabItem { Label("Customers", systemImage: "person.2") }
}
```

---

## Custom Containers — `ForEach(subviews:)` (iOS 18+)

iOS 18 introduced a `ForEach(subviews:)` API that lets you build container views that iterate over their `@ViewBuilder` children — like `List` and `Section` do internally.

```swift
// ✅ Custom card stack container
struct CardStack<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 12) {
            ForEach(subviews: content) { subview in
                subview
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// Usage
CardStack {
    OrderSummaryView(order: order1)
    OrderSummaryView(order: order2)
    OrderSummaryView(order: order3)
}
```

---

## `MeshGradient` — Backgrounds (iOS 18+)

`MeshGradient` creates smooth, multi-point color blends. Use for decorative backgrounds and hero images — not for content areas.

```swift
// ✅ Static mesh gradient background — colors come from the app's design tokens
MeshGradient(
    width: 2,
    height: 2,
    points: [
        [0, 0], [1, 0],
        [0, 1], [1, 1]
    ],
    colors: [
        Color.appAccentPrimary, .mint,
        Color.appAccentSecondary, .teal
    ]
)
.ignoresSafeArea()

// ❌ Do not hardcode raw colors — use the app's design-token accent colors
MeshGradient(
    width: 2, height: 2,
    points: [[0,0],[1,0],[0,1],[1,1]],
    colors: [.green, .mint, .blue, .teal]  // wrong — use token colors
)
```

---

## Liquid Glass (iOS 26+)

iOS 26 introduced the Liquid Glass design language. Use it for floating controls and overlay chrome — never on primary content. Gate with `#available(iOS 26, *)` and fall back to `.ultraThinMaterial` when supporting iOS 18–18.x.

```swift
// ✅ Configured glass on a floating control — apply glassEffect AFTER layout modifiers
Button("Scroll to Top", systemImage: "chevron.up") { scrollToTop() }
    .padding()
    .glassEffect(.regular.tint(.accentColor).interactive(),
                 in: .rect(cornerRadius: 16))

// ✅ System button styles
Button("Confirm") { confirm() }.buttonStyle(.glassProminent)  // or .glass

// ✅ Multiple glass elements near each other: wrap in a GlassEffectContainer
// (required for correct blending/morphing, and cheaper than N separate effects)
GlassEffectContainer {
    HStack {
        FilterChip("Open").glassEffect()
        FilterChip("Done").glassEffect()
    }
}

// ✅ Morphing between states: same glassEffectID + @Namespace
@Namespace private var glassNS
// collapsed and expanded views each declare:
.glassEffect().glassEffectID("fab", in: glassNS)

// ✅ Availability gating
if #available(iOS 26, *) {
    controls.glassEffect()
} else {
    controls.background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
}

// ❌ Glass effect on primary content — reduces readability
List(orders) { order in
    OrderRow(order: order)
        .glassEffect()  // wrong — glass is for overlay/floating UI
}
```

---

## HIG Conventions — Empty States, Labels, Tap Targets

```swift
// ✅ ContentUnavailableView for empty/missing states — never a custom VStack
ContentUnavailableView("No Orders", systemImage: "tray",
                       description: Text("Orders you create appear here."))
// ✅ Built-in variant for empty search results
ContentUnavailableView.search(text: searchText)

// ✅ Label for icon+text pairs — never a manual HStack (loses a11y + style adaptivity)
Label("Schedule", systemImage: "calendar")

// ✅ LabeledContent for value rows and labeled controls in a Form
LabeledContent("Total", value: order.total, format: .currency(code: "USD"))
LabeledContent("Volume") { Slider(value: $volume) }
```

- Interactive targets must be at least **44×44 points** — pad small icons, don't shrink hit areas.
- Never read `UIScreen.main.bounds` — use `containerRelativeFrame(_:)`, `GeometryReader` (last resort), or let layout flow.
- Avoid fixed frames on text-bearing views — they break under Dynamic Type (see accessibility.md).
- Use `bold()` not `fontWeight(.bold)`; use hierarchical styles (`.secondary`, `.tertiary`) instead of manual opacity.
- Centralize spacing/corner-radius/font constants in a shared design-constants enum (or the project's DESIGN.md tokens) — no magic numbers scattered through views.

---

## View Modifier Conventions

- Custom modifiers that apply to many views belong in `Shared/Components/` as `ViewModifier` conformances.
- Do not chain more than 5-6 modifiers on a single view inline — extract to a custom modifier.
- Never use `.appearance()` UIKit proxy calls from SwiftUI — use native SwiftUI styling.

```swift
// ✅ Custom modifier for a repeated pattern
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 2)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}
```

---

## Conditional Views

Prefer `if/else` inside `body` over opaque `AnyView` wrapping. `AnyView` defeats SwiftUI's diffing and should only appear when returning from a function that must erase the type.

```swift
// ✅ if/else in body — SwiftUI diffs correctly
var body: some View {
    if isLoading {
        ProgressView()
    } else {
        OrderList()
    }
}

// ❌ AnyView — erases type, breaks diffing
func content() -> AnyView {
    if isLoading { return AnyView(ProgressView()) }
    return AnyView(OrderList())
}
```
