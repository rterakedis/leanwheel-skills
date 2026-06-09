# iPadOS-Specific Patterns

> Updated: 2026-06-08 — iOS/iPadOS 19+
> iPadOS 18+ | Navigation, multi-window, pointer, drag-and-drop, and keyboard conventions.

---

## Primary Navigation — `NavigationSplitView`

`NavigationSplitView` is the required navigation pattern for iPad. Do not use `NavigationStack` alone as the root container on iPad — it produces an iPhone-style full-screen push stack and wastes the available screen width.

```swift
// ✅ Two-column split view (sidebar + detail)
NavigationSplitView {
    SidebarView(selection: $selectedItem)
} detail: {
    if let item = selectedItem {
        DetailView(item: item)
    } else {
        ContentUnavailableView("Select an item", systemImage: "sidebar.left")
    }
}

// ✅ Three-column split view (sidebar + content + detail)
NavigationSplitView {
    SidebarView(selection: $selectedCategory)
} content: {
    ContentListView(category: selectedCategory, selection: $selectedItem)
} detail: {
    DetailView(item: selectedItem)
}

// ❌ NavigationStack alone as the iPad root — wastes screen width
NavigationStack {
    SidebarView()
}
```

### Sidebar Selection State — Use `@SceneStorage`

Sidebar selection must survive app backgrounding and scene restoration. Use `@SceneStorage`, not `@State`, for the selected item identifier.

```swift
// ✅ Selection survives background/foreground cycles
@SceneStorage("sidebar.selectedItemID") private var selectedItemID: String?

// ❌ @State is lost when the app is backgrounded
@State private var selectedItemID: String?
```

### Column Visibility

```swift
// ✅ Control column visibility programmatically
@State private var columnVisibility = NavigationSplitViewVisibility.all

NavigationSplitView(columnVisibility: $columnVisibility) { ... }

Button("Toggle Sidebar") {
    columnVisibility = columnVisibility == .all ? .detailOnly : .all
}
```

---

## TabView with Sidebar Adaptation (iOS 18+)

On iPad, `TabView` with `.sidebarAdaptable` automatically converts the tab bar to a sidebar — no manual size-class branching required. Pair with the `Tab` wrapper.

```swift
// ✅ iOS 18+: Auto-adapting tab/sidebar
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
    .role(.search)
}
.tabViewStyle(.sidebarAdaptable)  // tab bar on iPhone, sidebar on iPad

// ❌ Manual size-class branching — unnecessary with .sidebarAdaptable
if horizontalSizeClass == .compact {
    TabBasedLayout()
} else {
    SplitViewLayout()
}
```

---

## Multi-Window Scene Support

iPad supports multiple windows of the same app. Design for it explicitly.

```swift
// ✅ App root — declare WindowGroup, use @Environment(\.openWindow)
@main struct MyApp: App {
    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
        }
        WindowGroup(id: "detail", for: Item.ID.self) { $itemID in
            if let id = itemID {
                DetailView(itemID: id)
            }
        }
    }
}

// ✅ Open a new window for an item
struct ContentView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open in New Window") {
            openWindow(id: "detail", value: selectedItem.id)
        }
    }
}
```

Do not store cross-window shared state in `@State` — use `@Observable` services injected via `@Environment` so all windows observe the same data.

---

## Drag and Drop — `Transferable` Protocol

Use the `Transferable` protocol with `.draggable()` and `.dropDestination()`. Do not use `NSItemProvider` directly for content types that can be expressed as `Transferable`.

```swift
// ✅ Make your model Transferable
struct Task: Transferable {
    var id: UUID
    var title: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .task)
    }
}

// ✅ Source — make a view draggable
TaskRow(task: task)
    .draggable(task)

// ✅ Destination — accept a drop
TaskListView()
    .dropDestination(for: Task.self) { droppedTasks, location in
        handleDrop(droppedTasks, at: location)
        return true
    }
```

---

## Pointer and Hover Interactions

Add `.hoverEffect()` to any tappable element that benefits from pointer feedback. On iPad with a trackpad or mouse, this provides standard hover highlighting without custom hit testing.

```swift
// ✅ Standard pointer highlight on hover
Button("Edit") { ... }
    .hoverEffect(.highlight)

// ✅ Custom hover state
struct InteractiveCard: View {
    @State private var isHovered = false

    var body: some View {
        CardContent()
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
```

---

## Keyboard Shortcuts

iPad apps with external keyboard support must provide shortcuts for primary actions.

```swift
// ✅ Primary actions get keyboard shortcuts
Button("New Task") { createTask() }
    .keyboardShortcut("n", modifiers: .command)

Button("Delete") { deleteSelected() }
    .keyboardShortcut(.delete, modifiers: .command)

// ✅ Discoverability via commands
struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Task") { createTask() }
                .keyboardShortcut("n", modifiers: .command)
        }
    }
}
```

---

## Toolbar Placement

iPad toolbars have more placement options than iPhone. Use them to put controls in the right location for the layout.

```swift
// ✅ Toolbar with correct iPad placements
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        EditButton()
    }
    ToolbarItem(placement: .topBarTrailing) {
        Button("Add", systemImage: "plus") { addItem() }
    }
    ToolbarItem(placement: .bottomBar) {
        Spacer()
        Text("\(count) items")
        Spacer()
    }
}
```

---

## Size Class Awareness

Read `horizontalSizeClass` to adapt layout between compact (iPhone, iPad slide-over) and regular (full-width iPad) environments. Do not hard-code device checks.

```swift
// ✅ Adapt to size class, not device
@Environment(\.horizontalSizeClass) private var horizontalSizeClass

var body: some View {
    if horizontalSizeClass == .compact {
        CompactLayout()
    } else {
        RegularLayout()
    }
}

// ❌ Device check — breaks for Catalyst, slide-over, and future form factors
if UIDevice.current.userInterfaceIdiom == .pad { ... }
```

---

## iPadOS Anti-Patterns

- **Forcing iPhone layout on iPad** — using `NavigationStack` alone, single-column layout, or ignoring `horizontalSizeClass` = regular.
- **Using sheet for content that belongs in the detail column** — if `NavigationSplitView` is in use, secondary content goes in the detail column, not a modal sheet.
- **Ignoring multi-window** — storing navigation state in app-global singletons that conflict across windows. Use `@SceneStorage` and per-window `@Environment`-injected services.
- **Missing keyboard shortcut support** — iPad apps attached to a keyboard are expected to behave like lightweight Mac apps for primary actions.
- **Not supporting right-click / long-press context menus** — add `.contextMenu` to any item where secondary actions exist.
- **Old `TabView` content embedding** — use `Tab` wrapper with `.sidebarAdaptable` instead of `.tabItem { }` for proper iPad sidebar adaptation (iOS 18+).
