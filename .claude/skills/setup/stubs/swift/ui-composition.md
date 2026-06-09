# UI Composition & Layout Rules

> Updated: 2026-06-08 — iOS/iPadOS 19+
> iOS 18+ | Preventing massive views, subview extraction, layout decisions, and new container APIs.

---

## The 50-Line Rule for View Body

If `var body: some View` exceeds ~50 lines, it must be decomposed. This is not a style preference — large bodies create re-render surface area and make conditional logic harder to audit.

Decomposition priority order:
1. Extract to a private computed property returning `some View` (zero overhead, stays in same file)
2. Extract to a private nested `struct` view (use when the subview has its own `@State`)
3. Extract to a separate file in the same feature folder (use when the component is reused or complex)

```swift
// ✅ Computed property extraction — stays in same file, no overhead
struct OrderListView: View {
    var body: some View {
        VStack {
            headerSection
            orderList
            footerSection
        }
    }

    private var headerSection: some View {
        HStack { ... }
    }

    private var orderList: some View {
        List(orders) { OrderRow(order: $0) }
    }
}

// ✅ Nested struct — when the subview needs its own @State
private struct ExpandableOrderRow: View {
    let order: Order
    @State private var isExpanded = false

    var body: some View { ... }
}
```

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
// ✅ Static mesh gradient background
MeshGradient(
    width: 2,
    height: 2,
    points: [
        [0, 0], [1, 0],
        [0, 1], [1, 1]
    ],
    colors: [
        Color.appAccentLawn, .mint,
        Color.appAccentSnow, .teal
    ]
)
.ignoresSafeArea()

// ❌ Do not hardcode semantic colors — use app accent colors per season
MeshGradient(
    width: 2, height: 2,
    points: [[0,0],[1,0],[0,1],[1,1]],
    colors: [.green, .mint, .blue, .teal]  // wrong — use Color.appAccent(for:)
)
```

---

## Liquid Glass Effect (iOS 19+)

iOS 19 introduced the Liquid Glass design language. Use `glassEffect()` for floating action buttons and overlay controls — not for primary content areas.

```swift
// ✅ Glass effect for a floating control
Button("Scroll to Top", systemImage: "chevron.up") {
    scrollToTop()
}
.padding()
.glassEffect()

// ❌ Glass effect on primary content — reduces readability
List(orders) { order in
    OrderRow(order: order)
        .glassEffect()  // wrong — glass is for overlay/floating UI
}
```

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
