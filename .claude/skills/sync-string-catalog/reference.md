# Xcode MCP server — notes behind `scripts/xcode-catalog-sync.py`

<!-- FIELD: trial-and-error knowledge measured on Xcode 27.0 (2026-10-30). Not in Apple's docs.
     Retire a line only when a citation shows the mechanism changed — see stubs/swift/PROVENANCE.md. -->

Read only when changing the script or debugging a `CATALOG: unavailable` result.

## What the server is

- Xcode 26.3+ ships an MCP server, started with `xcrun mcpbridge`. It speaks JSON-RPC 2.0 over
  stdio (protocol `2025-06-18`). It needs **Xcode running** with MCP enabled in
  Settings → Intelligence; `mcpbridge` is only a bridge to the live IDE.
- The driver's sequence: `initialize` → `notifications/initialized` → `XcodeOpenWorkspace`
  (path to **this checkout's** `.xcodeproj`/`.xcworkspace`) → `BuildProject` (repeat) →
  `XcodeCloseWorkspace` if the driver opened it (`XcodeListWorkspaces` first, to know).

## Footguns, each found the hard way

1. **Approval gate.** Every tool except `XcodeOpenWorkspace` / `XcodeNewProject` fails with
   "This agent isn't approved" until a project has been opened by that agent. Opening is what
   raises Xcode's approval prompt. The driver therefore tolerates a failing
   `XcodeListWorkspaces` and goes straight to open; an unanswered prompt ends in the
   `--timeout` (default 900 s), never a hang.
2. **`structuredContent` may be empty.** mcpbridge fills `content[].text` reliably and
   `structuredContent` sometimes; parse the text as JSON when the structured field is absent.
3. **One build is not always enough.** After a source revert, the catalog kept the old value
   through the build that compiled the revert and only caught up on the next. Build until two
   consecutive builds leave every catalog byte-identical, capped at 4; an in-sync tree pays one
   extra no-op build.
4. **Xcode re-sorts keys.** A key hand-inserted out of order is moved on the next IDE build,
   inflating the line diff. The driver diffs HEAD vs working file as **parsed JSON** and reports
   `+` / `-` / `~` keys, or "key order only".
5. **"In sync" is a real answer.** Xcode rewrites a catalog only when the extracted strings
   differ from it; a clean build of an in-sync tree leaves the file byte-identical.
6. **Open the checkout's own project.** Opening `main`'s project builds `main`'s strings and
   rewrites `main`'s catalog — the drift you were trying to prevent, created on purpose.
7. **Never hand-edit keys into the catalog.** That is the origin of every observed drift; the
   catalog is build output, and the fix for a missing key is a source change plus this sync.

## `BuildProject` result shape used

`buildResult` (string), `elapsedTime` (seconds), `errors[]` with `classification`
(`error` / `warning`), `filePath`, `lineNumber`, `message`. Only `classification == "error"`
fails the sync (exit 2: "build failed — catalog not trusted").

## Fallback without MCP — documented, not shipped

Prior art from other projects: `xcrun xcstringstool sync <catalog> --stringsdata <files…>`,
fed from `DerivedData/**/*.stringsdata`, with a `--check` mode in CI. Known pitfalls: skip
`GeneratedStringSymbols_*.stringsdata`; filter stale `.stringsdata` from targets no longer
built. It is **not** wired in because (a) it is unverified here, and (b) two writers for one
file is itself a drift mechanism — if `xcstringstool`'s output differs from Xcode's by so much
as key order, the IDE build on the next machine produces the surprise diff again. Revisit only
if a CI machine without Xcode must gate on the catalog; then prove byte-identity against an IDE
build first.

## Other mcpbridge tools seen (untested — do not build on yet)

`RenderPreview`, `RunSomeTests`, `GetBuildLog`, and others. `RenderPreview` might later serve
`/design-verify` for SwiftUI previews without a simulator; `GetBuildLog` could replace tailing
`.leanwheel/logs/build-test.log`. None has been exercised; treat the names as a lead, not a
capability.
