# Xcode Project & Build-Setting Footguns

<!-- FIELD: predominantly trial-and-error knowledge from shipping projects. Protected from
     research-driven rewrites — see PROVENANCE.md before editing. -->

Things about the Xcode project itself — not the Swift — that break a build or ship a broken
app, and give you a misleading error or none at all. Nothing here is discoverable by reading
source code.

---

## Exclude `CLAUDE.md` from the build, before you add the second one

**Set this at project level, in both Debug and Release, in any Xcode project that will carry
nested `CLAUDE.md` files:**

```
EXCLUDED_SOURCE_FILE_NAMES = "CLAUDE.md"
```

Why: modern Xcode projects use synchronized folder groups
(`PBXFileSystemSynchronizedRootGroup`), which sweep every file in a directory into the target
— including markdown, into **Copy Bundle Resources**. Two or more `CLAUDE.md` files anywhere
in the tree both try to land at `YourApp.app/CLAUDE.md`, and the build fails with:

```
error: Multiple commands produce '.../YourApp.app/CLAUDE.md'
```

There is nothing wrong with any source file, and the error names neither `CLAUDE.md`'s
directory nor the fact that a *documentation* file is being bundled.

This is the setting that makes the tiered-CLAUDE.md convention (a nested file next to the
code it governs) safe at all. **Do not remove it**, and re-add it to any new target that does
not inherit the project-level value.

The same hazard applies to any repeated non-source filename a synchronized folder sweeps in —
`README.md`, `.env.example`, per-directory `notes.md`. Add them to the same setting.

---

## Build settings live in project × target × configuration — and secondary targets inherit silently

A setting is not "on" because you set it once. Each project has a project-level config list
and one config list **per target**, each with a Debug and a Release entry. A value set on the
project applies only where a target does not override it, and a target that carries **no
explicit value** silently inherits — which reads identically to "correctly configured" in the
Build Settings UI.

Practical consequences:

- After changing a setting, **verify by grepping the project file**, not by looking at the UI:
  `grep -n SETTING_NAME YourApp.xcodeproj/project.pbxproj`. Count the hits and know which
  config list each belongs to; state the expected count in whatever doc records the decision.
- **Enumerate the secondary targets** — widget/app extensions, test bundles, watch apps — and
  decide for each. Test bundles never ship, so most settings do not matter for them; an
  **extension that ships** does, and it is the one most often missed.
- An *explicit* value that differs from the project's is sometimes correct, not a gap — e.g. a
  test bundle explicitly disabling String Catalog symbol generation because it owns no
  catalog. Record why, or someone will "fix" it for consistency.

---

## Missing capabilities fail at runtime, never at compile time

Capabilities (Target → **Signing & Capabilities**) — iCloud/CloudKit, In-App Purchase, Push
Notifications, Background Modes, App Groups, HealthKit — are entitlements, not imports. If one
is missing the code still compiles: the app crashes on launch, or the feature silently fails
with an opaque error at the point of first use.

So a build that succeeds proves nothing about capability configuration. When a feature needs a
capability, the story that adds the feature adds the capability, and the verification is
**running the thing on a signed build**, not compiling it.

`No such module 'CloudKit'` is the one case that *does* surface at compile time — and it means
the capability was never added, not that a file is missing an import.

---

## Scheme settings are per-machine, not in the project file

**Scheme → Run → Options → StoreKit Configuration** (and the other Run-options toggles) are
stored in per-user scheme data, not in the shared project. Clone the repo on a new machine and
the setting is gone.

The symptom is a purchase flow that returns `.userCancelled` immediately, or products that
never load, on a checkout where nothing about the code changed. Anything a fresh clone must
re-configure by hand belongs in the project's setup doc as an explicit step — it will not be
inferred from a failing build, because the build passes.

---

## Xcode's Issue Navigator caches stale warnings — trust a clean `xcodebuild` run

A warning that no longer matches current source can persist in the Issue Navigator across
incremental builds. Chasing it means editing correct code.

Ground truth is a fresh command-line run. Clear the cache with **Product → Clean Build Folder**
(⇧⌘K) when the Navigator and the terminal disagree, and believe the terminal.

Related, same shape: an `EXC_BAD_ACCESS` deep in SwiftUI internals (a refcount crash in
`initializeWithCopy`, or similar) **immediately after adding or removing a stored property on
a large view** is usually a stale incremental build — the stored-property layout changed and
the installed bundle disagrees with the debug dylib. It is not a code defect and no amount of
re-reading the diff will find it. `xcodebuild clean build`, then re-run.

---

## Keep the build at zero warnings

Treat every compiler warning as a defect to fix **in the same change** — deprecations,
redundant nil-coalescing on a non-optional, unused results, `await`/`try` on a non-throwing
call. A codebase that tolerates warnings loses the signal entirely, and clearing an accumulated
backlog costs a dedicated pass.

Make sure the build invocation you actually run **prints** `warning:` lines. A filter tuned to
show only `error:` and `BUILD` is how a zero-warning policy quietly becomes unenforced — see
`simulator.md` § *Building and testing from the command line*.

**Stale localization keys** show as "References to this key could not be found in source code"
on a String Catalog entry. Confirm before deleting: an `extractionState: stale` key is
genuinely unreferenced, but check whether the string **moved** rather than died — see
`localization.md`.

---

## File auto-discovery covers Swift, not resources

With synchronized folder groups, a new `.swift` file in the right directory is compiled with no
project edit. Non-Swift resources — `.xcstrings`, `.json`, `.storekit`, asset catalogs — may
still need adding to **Copy Bundle Resources** by hand. A resource that is present on disk,
committed, and simply not in the bundle fails at runtime with "file not found" for a file you
can see.
