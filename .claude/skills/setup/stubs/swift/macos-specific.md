# macOS-Specific Patterns

> Updated: 2026-06-08 — macOS 15+ (Sequoia)
> macOS 15+ (Sequoia) | Scene management, menus, toolbar, window, and Mac-idiomatic conventions.

---

## Scene Architecture

macOS apps can present multiple scene types. Declare each in the `App` body.

```swift
// ✅ Full scene declaration for a document-agnostic app
@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands { AppCommands() }

        Settings {
            SettingsView()
        }

        MenuBarExtra("MyApp", systemImage: "star") {
            MenuBarView()
        }
    }
}

// ✅ Document-based app
@main struct EditorApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MyDocument()) { file in
            EditorView(document: file.$document)
        }
    }
}
```

**Do not** use `UIApplicationDelegate` lifecycle hooks — that is UIKit. macOS SwiftUI apps use `Scene` conformances exclusively.

---

## Settings Scene

The `Settings` scene renders in the standard macOS Preferences window (⌘,). Never use a sheet or modal for app settings on macOS.

```swift
// ✅ Settings rendered in native Preferences window
Settings {
    TabView {
        GeneralSettingsView()
            .tabItem { Label("General", systemImage: "gear") }
        AccountSettingsView()
            .tabItem { Label("Account", systemImage: "person") }
    }
    .frame(width: 500)
}

// ✅ Open settings from a menu item or button
@Environment(\.openSettings) private var openSettings

Button("Preferences…") { openSettings() }
    .keyboardShortcut(",", modifiers: .command)

// ❌ Sheet used for settings — not Mac-idiomatic
Button("Settings") { showSettingsSheet = true }
    .sheet(isPresented: $showSettingsSheet) { SettingsView() }
```

---

## Menu Bar Commands

All primary actions must be reachable from the menu bar. Use `Commands` to add or replace default menu groups.

```swift
// ✅ App commands declared at the scene level
struct AppCommands: Commands {
    @FocusedBinding(\.selectedItem) private var selectedItem

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Project…") { createProject() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        CommandMenu("Item") {
            Button("Duplicate") { duplicate(selectedItem) }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(selectedItem == nil)

            Divider()

            Button("Delete", role: .destructive) { delete(selectedItem) }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(selectedItem == nil)
        }
    }
}
```

Use `@FocusedBinding` or `@FocusedValue` to pass state from the focused window into commands — do not use global singletons.

---

## `MenuBarExtra`

For menu bar status items, use `MenuBarExtra`. It supports both a simple menu and a popover-style window.

```swift
// ✅ Menu-style menu bar item
MenuBarExtra("Sync Status", systemImage: "arrow.triangle.2.circlepath") {
    Button("Sync Now") { syncService.sync() }
    Divider()
    Button("Quit") { NSApplication.shared.terminate(nil) }
}
.menuBarExtraStyle(.menu)

// ✅ Window-style menu bar item (popover)
MenuBarExtra("MyApp", systemImage: "star.fill") {
    MenuBarContentView()
}
.menuBarExtraStyle(.window)
```

---

## `Table` — Native Mac Data Tables

Use `Table` for displaying structured data with sortable columns. Do not use `List` for tabular data that benefits from column headers and multi-column layout.

```swift
// ✅ Sortable table with multiple columns
@State private var sortOrder = [KeyPathComparator(\Customer.name)]
@State private var selection = Set<Customer.ID>()

Table(customers, selection: $selection, sortOrder: $sortOrder) {
    TableColumn("Name", value: \.name)
    TableColumn("Email", value: \.email)
    TableColumn("Status") { customer in
        StatusBadge(status: customer.status)
    }
}
.onChange(of: sortOrder) { customers.sort(using: $0) }

// ❌ List used for tabular data — no column headers, no multi-select
List(customers) { customer in
    HStack {
        Text(customer.name)
        Text(customer.email)
    }
}
```

---

## Window Management

Open additional windows using the `openWindow` environment action. Each window is a scene instance — do not use sheets as a substitute for real windows on macOS.

```swift
// ✅ Open a typed window
@Environment(\.openWindow) private var openWindow

Button("Open in New Window") {
    openWindow(id: "detail", value: item.id)
}

// ✅ Declare the typed window in App
WindowGroup(id: "detail", for: Item.ID.self) { $itemID in
    if let id = itemID { DetailView(itemID: id) }
}
.defaultSize(width: 800, height: 600)
.restorationBehavior(.disabled)
```

---

## Toolbar Styles

macOS toolbars have explicit style options. Set them at the `WindowGroup` or view level.

```swift
// ✅ Unified toolbar (title inline with toolbar items)
ContentView()
    .toolbarTitleDisplayMode(.inline)

// ✅ Toolbar with principal item (centered title area)
.toolbar {
    ToolbarItem(placement: .principal) {
        Picker("View", selection: $viewMode) {
            Label("List", systemImage: "list.bullet").tag(ViewMode.list)
            Label("Grid", systemImage: "square.grid.2x2").tag(ViewMode.grid)
        }
        .pickerStyle(.segmented)
    }
    ToolbarItem(placement: .automatic) {
        Button("Add", systemImage: "plus") { addItem() }
    }
}
```

---

## File Operations

Use SwiftUI's declarative file importers and exporters rather than presenting `NSOpenPanel` directly.

```swift
// ✅ File importer
@State private var showImporter = false

Button("Import…") { showImporter = true }
    .fileImporter(
        isPresented: $showImporter,
        allowedContentTypes: [.pdf, .plainText]
    ) { result in
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            processFile(at: url)
        case .failure(let error):
            print(error)
        }
    }

// ✅ File exporter
.fileExporter(
    isPresented: $showExporter,
    document: exportDocument,
    contentType: .pdf
) { result in ... }

// ❌ Direct NSOpenPanel — bypasses SwiftUI security-scoped resource handling
let panel = NSOpenPanel()
panel.runModal()
```

---

## Keyboard Shortcuts

Standard shortcuts to implement without exception:

| Action | Shortcut |
|---|---|
| New | ⌘N |
| Open | ⌘O |
| Save | ⌘S |
| Save As | ⇧⌘S |
| Close window | ⌘W |
| Preferences | ⌘, |
| Find | ⌘F |
| Delete selected | ⌘⌫ |
| Select all | ⌘A |
| Undo / Redo | ⌘Z / ⇧⌘Z |

---

## Context Menus and Right-Click

Every interactive item that has secondary actions must support right-click via `.contextMenu`. On macOS this is a hard user expectation.

```swift
// ✅ Context menu on a list row
ForEach(items) { item in
    ItemRow(item: item)
        .contextMenu {
            Button("Open in New Window") { openWindow(id: "detail", value: item.id) }
            Button("Duplicate") { duplicate(item) }
            Divider()
            Button("Delete", role: .destructive) { delete(item) }
        }
}
```

---

## macOS Anti-Patterns

- **Using sheet for Settings** — macOS has a `Settings` scene. Using a sheet breaks ⌘, and violates platform conventions.
- **Missing menu bar commands** — macOS users muscle-memory menu bar shortcuts. Every primary action needs a `Commands` entry.
- **`List` for tabular data** — if the content is inherently columnar, use `Table`.
- **No right-click context menus** — macOS users right-click everything. Any list row, grid cell, or interactive element with secondary actions must have `.contextMenu`.
- **Presenting `NSOpenPanel` directly** — use `.fileImporter` / `.fileExporter` for proper security-scoped resource handling.
- **Ignoring window restoration** — by default macOS restores window state between launches. Design scene-level state (selection, scroll position) to serialize correctly via `@SceneStorage`.
- **UIKit idioms in Mac Catalyst** — if building a Catalyst app, audit for `UIAlertController`, `UIActivityViewController`, and `UINavigationController` — each has a native SwiftUI or AppKit equivalent.
