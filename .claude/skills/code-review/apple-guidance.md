# Apple guidance reads — read only when `docs/setup/swift/` exists

Applied from Step 2, before beginning the passes.

Always (Apple project):
- `docs/setup/swift/anti-patterns.md` and `docs/setup/swift/state-management.md` — the rejection criteria for Pass A and Pass C.

Only when the diff touches the named area:
- `docs/setup/swift/core-data-cloudkit.md` (if present) — the data model, persistence, or sync.
- `docs/setup/swift/demo-data-and-copy.md` — seed/preview data, or copy on a regulated surface.
- `docs/setup/swift/xcode-footguns.md` — the `.xcodeproj`.
- `docs/setup/swift/iphone-duo.md` (if present) — layout geometry, toolbar/tab-bar construction, or sheet presentation.
- `docs/setup/swift/ipados-specific.md` (if present) — navigation, split view, or multi-window code.
- `docs/setup/swift/macos-specific.md` (if present) — menus, windows, settings, or toolbar code.
