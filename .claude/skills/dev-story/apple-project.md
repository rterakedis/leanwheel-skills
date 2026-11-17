# Apple / Swift projects — read only when `docs/setup/swift/` exists, or an `.xcodeproj` / `Package.swift` is present

Applied from Activation step 4, Execution, and Build & Test Gate step 1.

## Guidance routing (Activation step 4)

Read the files relevant to this story's tasks before implementing:

- Data models, services, or `@Observable` → `docs/setup/swift/state-management.md`
- Async loading, background work, or threading → `docs/setup/swift/concurrency.md`
- New features, services, or project structure → `docs/setup/swift/architecture.md`
- Views or UI components → `docs/setup/swift/ui-composition.md` and `docs/setup/swift/accessibility.md`
- Adding tests → `docs/setup/swift/testing.md`
- Project uses SwiftData and the story touches models, queries, or persistence → `docs/setup/swift/swiftdata.md`
- Project uses Core Data / `NSPersistentCloudKitContainer` and the story touches the model, persistence, or sync → `docs/setup/swift/core-data-cloudkit.md` — every schema rule there is a launch crash, and a deployed violation is a permanently wrong Production schema
- User-facing strings → `docs/setup/swift/localization.md`
- Seed/preview/demo records, or copy for a regulated or consequential surface (tax, health, legal, safety, financial) → `docs/setup/swift/demo-data-and-copy.md`
- Changes to the Xcode project itself — build settings, capabilities, targets, bundled resources, schemes → `docs/setup/swift/xcode-footguns.md` (these fail at runtime or with a misleading error, never at compile time)
- A persisted model entity added/changed, user-facing views added, or launch behavior touched → `docs/setup/swift/testability.md` (seed scenarios, launch arguments, deep-link routes, accessibility identifiers)
- The app must be *rendered* — screenshot verification, adding a flow, or stabilizing a screen → `docs/setup/swift/simulator.md` (`scripts/sim.sh`, the screenshot matrix, flow conventions)
- `docs/setup/swift/anti-patterns.md` if present
- `docs/setup/swift/iphone-duo.md` if it exists and the story touches layout, toolbars/tab bars, sheets, or any custom container
- `docs/setup/swift/ipados-specific.md` if it exists and the story touches navigation, split view, drag-and-drop, pointer, keyboard, or multi-window
- `docs/setup/swift/macos-specific.md` if it exists and the story touches menus, windows, toolbar, settings, tables, or file operations

## Keep testability current as you go (Execution)

Projects with `docs/setup/swift/testability.md` (canonical, DD-34):

- A task that adds or changes a persisted model entity updates the `SeedScenario` registry (at minimum `.typical` and `.edge`) in the same task.
- New user-facing views get the exact `.accessibilityIdentifier`s the story's Design Contract names.
- A task that adds a screen adds its deep-link route in the same task.

## Build + test command (Build & Test Gate step 1)

Mandatory on Apple projects.

```bash
# Xcode project/workspace — quiet, full log on disk, last 40 lines in context
mkdir -p .leanwheel/logs && [ -f .leanwheel/logs/.gitignore ] || echo '*' > .leanwheel/logs/.gitignore   # self-ignoring, like .leanwheel/sim/
xcodebuild -quiet -scheme {scheme} -destination 'platform=iOS Simulator,name={device}' build test \
  2>&1 | tee .leanwheel/logs/build-test.log | tail -n 40
# or SwiftPM
swift build -q && swift test -q 2>&1 | tee .leanwheel/logs/build-test.log | tail -n 40
```

`{device}` = a simulator the installed Xcode ships — `scripts/sim.sh doctor` lists them.
