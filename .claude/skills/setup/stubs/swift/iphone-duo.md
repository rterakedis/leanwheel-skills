# iPhone Duo — Foldable Layout Patterns

> Updated: 2026-09-20 — iOS 27.1+ / Xcode 27.1
> Reserved regions, arrangement views, vertical bars, and device poses.
> Sources: HIG "Designing for iPhone Duo" (2026-09-09) and "Preparing your app for iPhone Duo".

iPhone Duo has a **compact-width outer display** and a **regular-width inner display**, joined
by a hinge. The device is used open, closed, partially folded, rotated, and in Split View, so a
single app can appear at many sizes within one session. Everything here is still *iOS* design —
the patterns in the other files still apply.

**The one-line rule:** an app that already resizes correctly for iPad, Mac, and iPhone Mirroring
needs almost no Duo-specific work. Most Duo bugs are resizing bugs that were always there.

---

## Build to Resize

Compact vs. regular horizontal size class is now a **phone** distinction, not an iPhone-vs-iPad
distinction. Outer display = compact width. Inner display = regular width. Those two layouts
cover every pose; do not author a layout per pose.

```swift
// ✅ Size-class driven — one code path serves outer, inner, and Split View
@Environment(\.horizontalSizeClass) private var horizontalSizeClass

var body: some View {
    if horizontalSizeClass == .compact { CompactLayout() } else { RegularLayout() }
}

// ❌ Anything tied to a specific display
UIScreen.main.bounds.width           // no
if UIDevice.current.userInterfaceIdiom == .phone { ... }   // no
.frame(width: 393)                   // no — fixed iPhone dimensions
if width > 430 { ... }               // no — hand-rolled breakpoints
```

Rules:

- Size views **relative to their container**, not to device dimensions.
- Base layout math on the **scene or containing view's bounds**, never screen dimensions.
- Prefer system containers — `NavigationSplitView`, `TabView`, `NavigationStack`,
  `ArrangementView`. They handle the fold and camera occlusions for free.
- Build with layout margins and **horizontal** safe-area insets.
- UIKit: adopt Auto Layout, and use automatic trait tracking to observe
  `horizontalSizeClass` / `verticalSizeClass`. Do not branch on `userInterfaceIdiom` or
  `UIInterfaceOrientation` for layout.

`NavigationSplitView` collapses to a single pane on the outer display and expands on the inner
display, exactly as it adapts between compact and regular elsewhere — no extra work.

---

## Reserved Regions

Beyond safe areas, a Duo display carries **reserved regions**: areas your content should avoid.
Two kinds:

| Kind | What it is | When it's active |
|---|---|---|
| `occlusion` | Hardware covers content — outer front camera (expands into the Dynamic Island), inner front camera | Outer camera: always. Inner camera: only while the camera is active. |
| `division` | The **folding region** splits one display into two usable areas | Only when the device is partially open |

System components (alerts, sheets, context menus, split views) adapt automatically. **Custom
layouts must query.** A region is returned whether or not it is currently active — check
`isActive`.

```swift
// ✅ Custom layout that keeps content clear of the fold and cameras
GeometryReader { proxy in
    RegionAvoidingLayout(regions: proxy.reservedRegions(kind: .occlusion)) {
        ForEach(items) { ItemView($0) }
    }
}
```

Each `ReservedRegion` carries `id`, `frame` (view coordinate space, margins included),
`margins`, `isActive`, and `kind`. UIKit: `UIView.reservedRegions(kind:options:)`.

RTL: the system mirrors region geometry by default so a `Layout` — which already flips its
subviews — needs no special handling. Pass `LayoutDirectionBehavior.fixed` only when you are
positioning against the *physical* hardware location and want no mirroring.

**Layout advice around the fold:**

- Prefer a container that adapts itself (a split view narrows its panes) over hand-positioning.
- In grids, prefer an **even** number of columns so content divides cleanly at the hinge.
- Move only what must move. Controls that jump or vanish as the user folds are hard to track.

---

## Arrangement Views

`ArrangementView` (SwiftUI) / `UIArrangementViewController` (UIKit) is a container for a
**primary** and **secondary** view that reflows around reserved regions. Two styles:

- **Split** (`.split`, the default `.automatic` resolves here) — side by side when wider than
  tall, stacked when taller than wide. Use it where you'd reach for `HStack` / `VStack`.
- **Overlay** (`.overlay`) — primary layered over secondary when no division is active (closed
  or fully open). When partially folded, the two views move to opposite sides of the fold. Use
  it where you'd reach for `ZStack` — media player controls over a video surface.

```swift
ArrangementView {
    PlayerControls()
} secondary: {
    VideoPlayer()
}
.arrangementViewStyle(.overlay)

// Constrain which axes a split may use
.arrangementViewStyle(.split.axes(.horizontal))
```

Sizing modifiers: `splitArrangementLayoutRatio(_:)`,
`splitArrangementLayoutSize(minWidth:…)`, `splitArrangementFixedLayoutSize(horizontal:vertical:)`,
and `overlayArrangementEdge(_:)`.

**Do not** put an `ArrangementView` inside a `NavigationSplitView`, `List`, `ScrollView`, or
other container that could make part of it unreachable. It lays out content and does **not**
handle navigation — keep navigation containers *around* it, never inside it.

---

## Vertical Bars

On the outer display — and in the leading/trailing position on the inner display in landscape —
the system moves navigation bars, toolbars, and tab bars to the **side** to preserve vertical
space. You get this for free from `NavigationStack` / `NavigationSplitView` + `toolbar(content:)`.
A hand-rolled bar built on `UIToolbar`, `UINavigationBar`, or `UITabBar` does not participate.

Exceptions: inspectors stay horizontal; in a multi-column split view the sidebar/content bars
stay horizontal while the detail bar goes vertical; the inner display in portrait keeps
horizontal bars.

```swift
// ✅ Every item gets BOTH a title and a symbol
ToolbarItem(placement: .primaryAction) {
    Button("New Note", systemImage: "square.and.pencil") { … }
}
.visibilityPriority(.high)        // survives compression longer
```

Why both: vertical presentation uses the **icon** — an item with a title and no icon is *never*
presented vertically, and neither is an item built from a custom view. Horizontal presentation
prefers the icon; the overflow menu uses icon **and** title.

| Need | SwiftUI | UIKit |
|---|---|---|
| Which items may go vertical | `.axisBehavior(_:)` (`.horizontalOnly`, `.verticalPreferred`) | `axisBehavior` |
| Overflow order | `.visibilityPriority(_:)` | `visibilityPriority` |
| Always-in-overflow items | `ToolbarOverflowMenu` | `additionalOverflowItems` |
| Prominent trailing action (Done) | `.topBarPinnedTrailing` placement | `pinnedTrailingGroup` |
| Custom Back / Close | `ToolbarItem(placement: .cancellationAction)` | `leadingItemGroups` |
| Opt a sheet's bars out of vertical | `.toolbarVerticalBehavior(_:)` | `preferredVerticalBarBehavior` |
| Where the sheet sits | `.presentationPlacement(_:)` | `preferredPlacement` |
| Toolbar vs. tab bar under pressure | `ToolbarVerticalCompressionBehavior` | `UIVerticalBarCompressionBehavior` |
| Read the system's bar edge | `@Environment(\.toolbarVerticalEdge)` → `HorizontalEdge?` | `verticalBarEdge` trait |
| Extend a hero image under the bar | `.backgroundExtensionEffect()` | `UIBackgroundExtensionView` |

`toolbarVerticalEdge` is `nil` wherever the system never places a vertical bar — use it to
position *custom* floating UI, not to decide whether to draw your own bar.

Ordering: primary navigation (Back, Close) at the top, then prominent actions (Done), then the
original groupings. Items overflow bottom-to-top by default, so raise the priority of anything
frequently used or badge-bearing. Group with `ToolbarItemGroup` / `UIBarButtonItemGroup` rather
than inserting fixed spacers — groups re-space themselves as room changes. Keep text-only
buttons to a minimum; they can only live in a horizontal bar. Reserve the ellipsis symbol for
overflow, and fold any app-specific overflow menu into the system one.

**Don't override default bar placement.** Side bars are a core Duo pattern; moving them back
costs familiarity for no gain. Full-width, bar-free layouts are fine for immersive,
non-scrolling interfaces (a calculator) as long as nothing collides with the Dynamic Island or
status bar.

Split View on the inner display puts each app's controls on its **outer** edge — so account for
controls on the opposite edge too, via safe areas. Bar position is tied to hardware, so it does
**not** flip in right-to-left languages.

---

## Building and Verifying

- Build with the **iOS 27.1 SDK / Xcode 27.1** or later. Built against Xcode 26 or earlier, the
  app does not extend under the status bar and camera — it is letterboxed out of the full-screen
  experience.
- Preview poses with **Device Hub** in Xcode, or run on the simulated device.
- Walk every view, sheet, and popover in each pose and both orientations, and look for: content
  that doesn't resize, bars that stayed horizontal when they should have gone vertical, sheets
  and popovers that land awkwardly across the fold, and controls that end up *in* the fold.

**Games:** locking to portrait or landscape is allowed, but fill the screen in every pose.
Prefer changing aspect ratio over letterboxing or pillarboxing; if you must box, fill the
padding with artwork.

**Camera apps:** both displays have a front camera, and folding or rotating can change which
display your app is on — and therefore which way "the camera" points. Re-resolve the camera by
facing direction rather than caching a device. When fully open and capturing with the rear
camera, the outer display can act as a capture accessory preview.

---

## Anti-Patterns

- **Fixed widths, hardcoded breakpoints, or `UIScreen.main` math** — the three reliable ways to
  break on a device whose size changes mid-session.
- **A custom bar built on `UIToolbar` / `UINavigationBar` / `UITabBar`** — opts the app out of
  vertical presentation entirely.
- **Toolbar items with a title and no symbol** — silently excluded from vertical bars.
- **`ArrangementView` nested in a `NavigationSplitView`, `List`, or `ScrollView`** — parts of the
  arrangement become unreachable.
- **Custom layouts that ignore `reservedRegions`** — controls land in the fold or under a camera.
- **A layout per pose** — poses are a size problem; size classes already solve it.
- **Odd column counts in a grid** — content splits unevenly at the hinge.
