# Core Data + CloudKit — Survival Rules

<!-- FIELD: predominantly trial-and-error knowledge from shipping projects. Protected from
     research-driven rewrites — see PROVENANCE.md before editing. -->

> Applies only if the project uses `NSPersistentCloudKitContainer`. If it uses SwiftData,
> read `swiftdata.md` instead; if it uses plain Core Data with no sync, only the *Testing
> against the real schema* section applies.

`NSPersistentCloudKitContainer` is not "Core Data plus a checkbox". CloudKit imposes schema
restrictions Core Data does not, and it enforces them at **store load time** — which means a
violation is a hard crash on the first launch of the app, not a compile error and not a
sync warning. Every rule in the first section below has that same failure shape.

---

## The four schema rules — each one is a launch crash

| Rule | What happens if you break it |
|---|---|
| **Every attribute is `optional="YES"`** in the model. No exceptions. | CloudKit rejects non-optional attributes that have no default — the store fails to load and the app crashes on launch. |
| **No `ordered="YES"` relationships.** | CloudKit does not support ordered relationships — hard crash on launch. Model ordering as an explicit sort key (`queuePosition`, `sortIndex`) on the child entity. |
| **No uniqueness constraints on any entity.** | CloudKit rejects them — hard crash on launch. Enforce singletons in code (below). |
| **CloudKit container options are guarded by `#if !targetEnvironment(simulator)`.** | The Simulator has no iCloud account; attaching CloudKit there crashes at init. |

These stop being "avoid a launch crash" and become "permanently wrong Production schema"
the moment the model is deployed — see *Schema deployment* below.

### The generated Swift property must be optional too

Making the *attribute* optional and then declaring the *property* non-optional is the
tempting half-fix, because it removes a wall of `??` from call sites. It is wrong, and the
damage is deferred rather than avoided.

Applies to **object types only** — `Date`, `String`, `UUID`, `Decimal`, `Data`, and every
relationship. Scalar attributes (`Bool`, `Int16`, `Double`) bridge to non-optional Swift
scalars and are exempt.

```swift
// ❌ The type now lies. `??` below is dead code the compiler will warn about, and a nil
//    row traps at the Objective-C bridge — a crash with no Swift frame naming the field.
@NSManaged public var createdAt: Date

// ✅ The property tells the truth about what the store can hold.
@NSManaged public var createdAt: Date?
```

**Never "fix" the resulting compile error with `!` or `as!`.** That converts a degradable
nil into a crash at exactly the point where the data is least trustworthy — legacy rows,
rows that arrived from another device mid-migration, rows a failed import half-wrote.

Pin this with a test that parses the `.xcdatamodel` XML and the generated
`+CoreDataProperties.swift` files and fails naming any object-typed attribute whose Swift
property is non-optional. Put the full failure mode in the test's doc comment — that is
where someone debugging the red actually reads.

### Singletons: fetch-or-create, plus a reconciliation pass

With uniqueness constraints unavailable, a "there is exactly one settings row" invariant is
code, not schema:

```swift
static func fetchOrCreateSettings(in context: NSManagedObjectContext) throws -> AppSettings {
    let request = AppSettings.fetchRequest()
    request.fetchLimit = 1
    if let existing = try context.fetch(request).first { return existing }
    let created = AppSettings(context: context)
    try context.save()
    return created
}
```

That is necessary and **not sufficient**. Two devices that both run fetch-or-create before
either one's record syncs each create a row, and CloudKit merges both — a duplicate
"singleton" that no constraint will ever collapse. Ship a reconciliation service that
merges duplicates and run it at three points:

1. **At bootstrap**, before anything reads the singleton.
2. **On CloudKit import completion** (`NSPersistentCloudKitContainer.eventChangedNotification`,
   `.import` type, `succeeded == true`) — this is the moment a duplicate can appear.
3. **Inline in the fetch-or-create paths**, so a caller can never be handed one of two.

Merge deterministically (oldest `createdAt` wins, non-nil field values from the loser are
copied onto the winner) so two devices reconciling independently converge on the same row.

---

## Migrations — new optional attributes need none

A **new optional attribute with no default value** requires no model-version bump and no
migration. Core Data infers the change (lightweight migration) and existing rows read `nil`;
CloudKit replicates optional attributes as nullable, so old records simply carry `nil`.

This is why the all-optional rule is a gift as well as a tax: it makes almost every schema
change additive and downtime-free.

### Read-time fallback resolvers, not data migrations

When a new field supersedes an older one, do **not** backfill the store and do not guess a
default. Resolve at read time, in a service, so the resolution is unit-testable and legacy
rows keep rendering correctly:

```swift
/// New rows carry `distanceSource`. Rows written before it existed carry nil, and their
/// provenance can only be reconstructed from the legacy field. Only this resolver applies
/// the fallback — `distanceSourceEnum` is a literal accessor, for *writes*.
static func resolvedSource(for record: TripLog) -> DistanceSource? {
    if let source = record.distanceSourceEnum { return source }
    return record.legacyEntryMethod == "automatic" ? .gpsTrack : nil
}
```

Two corollaries that are easy to get wrong:

- **A superseded field is frozen, not repurposed.** Keep writing its existing vocabulary so
  older builds and restored backups stay readable, but never read it for display and
  **never overwrite it with a new meaning**. Overwriting one field's value with a different
  fact destroys provenance irrecoverably for every row written before the fix — there is no
  migration back from information that was never stored.
- **Split "why it happened" from "is it still outstanding".** An immutable reason field and
  a mutable workflow flag are two facts; collapsing them means clearing the flag also erases
  the reason.

---

## Schema deployment — the failure that only hits users

`NSPersistentCloudKitContainer` ships no schema file. It **infers** record types from the
model and creates them **lazily in Development** — the first time a Debug build actually
saves an object of that type. Development and Production are separate copies, and promoting
one to the other is a manual Console step that never happens on its own.

Consequences:

- An entity, attribute, or relationship that manual testing never exercised has **no record
  type in Development**, so it is absent from what gets promoted, and the first real user to
  create one gets a permanently failing sync. "I think I've used every entity" is not a check.
- **Environment is chosen by how the build is signed, not by a flag.** Xcode-to-device Debug
  builds talk to Development; TestFlight and App Store builds talk to **Production**.
- **Production changes are additive and permanent.** You can add record types and fields
  forever; you can never delete a record type, delete a field, or change a field's type. The
  only escape is a new container identifier, which orphans every user's data.

The fix is `initializeCloudKitSchema`, gated behind a debug launch argument so it never fires
on a normal launch — full pattern, constraints, and the deploy sequence in `testability.md`
(*`--init-cloudkit-schema`*). **Any model change → re-run it and re-deploy before the build
that needs it reaches TestFlight.** Schema ships *ahead* of code, never behind it.

Expect these in the Console diff and don't be alarmed: `_ckAsset` companion fields on string
and binary attributes, `___createTime` / `___etag` / `GRANT` boilerplate, and `Decimal`
attributes mirroring as `DOUBLE` (CloudKit has no decimal type — the local store stays
`Decimal` and remains the source of truth). A `-` line in the diff is the one thing to stop for.

---

## Testing against the real schema, never a mock

**Do not mock Core Data.** Instantiate the real stack in memory and let the real model
enforce itself:

```swift
let controller = PersistenceController(inMemory: true)
```

A mock repository passes while the schema is broken in exactly the ways above — a mock has
no `.xcdatamodel` to reject a non-optional attribute. Prefer a `/dev/null` store URL over
`NSInMemoryStoreType` so SQLite semantics (constraints, batch requests, fetched-results
behavior) still apply; see `testability.md`.

Three testing rules that cost real debugging time when missed:

- **`@MainActor` on any suite that touches `viewContext` directly.** Without it Swift Testing
  runs the suite off the main thread and it **deadlocks** — no failure message, no timeout
  you can read, just a hung run. Suites that only use `newBackgroundContext()` inside
  `context.perform { }` don't need it.
- **Never assert deletion via `isDeleted == true` after a save.** `isDeleted` is true only
  between `context.delete(obj)` and the next save; afterwards the object is evicted,
  `isDeleted` reverts to `false`, and `managedObjectContext` becomes `nil`. Full pattern and
  the correct assertions: `testing.md` § *Asserting deletion*.
- **`CoreData: error: +[Entity] Failed to find a unique match` in test output is log noise**
  from in-memory stores, not a failure. Don't chase it while the suite is green.

---

## Import discipline

Always `import CoreData` alongside `import SwiftUI` in any file that uses
`\.managedObjectContext` or a Core Data type. SwiftUI does not re-export CoreData, so the
environment key is simply invisible without the explicit import — and the resulting error
points at the environment key, not the missing import.

---

## Presentation and mutation rules

Core Data saves fire `NSManagedObjectContextObjectsDidChange`, which re-evaluates every
`@FetchRequest` and every view derived from one. That single mechanism is behind a cluster of
SwiftUI presentation bugs — zombie objects in sheets, covers that dismiss themselves,
count-derived gates that never fire. They are collected in `ui-composition.md`
§ *Presentation over persisted data*. Read that section before wiring any sheet, alert, or
cover over Core Data.
