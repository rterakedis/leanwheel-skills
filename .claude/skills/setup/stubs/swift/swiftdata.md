# SwiftData Rules

> Updated: 2026-07-19 — iOS 18+ (iOS 26 features flagged) / Swift 6.2
> Crash-class SwiftData rules: predicates, relationships, actor boundaries, CloudKit. **Applies only to projects using SwiftData** — on Core Data projects, state-management.md and testing.md's Core Data guidance governs instead. Never mix both frameworks for the same models.

---

## `#Predicate` — Compiles ≠ Works

`#Predicate` accepts a subset of Swift. Unsupported constructs **compile fine and crash at runtime** — the compiler will not save you.

```swift
// ❌ CRASHES AT RUNTIME — `== false` on isEmpty is not translatable
#Predicate<Trip> { $0.name.isEmpty == false }

// ✅ Use the prefix operator form
#Predicate<Trip> { !$0.name.isEmpty }
```

**Not supported inside a predicate** (runtime crash or silent failure): `hasSuffix`, `lowercased()`/`uppercased()`, `map`, `reduce`, `count(where:)`, `first(where:)`, regex matching, custom operators/functions, and any **computed property, `@Transient` property, or `Codable`-struct property** on the model — predicates can only touch stored, persisted properties.

```swift
// ✅ Supported string matching
#Predicate<Customer> { $0.name.starts(with: prefix) }                 // prefix
#Predicate<Customer> { $0.name.localizedStandardContains(searchText) } // user search

// ✅ Anything unsupported: fetch with a broader predicate, then filter in memory
let matched = try context.fetch(descriptor).filter { $0.displayName.hasSuffix("Inc.") }
```

---

## Models & Relationships

```swift
@Model
final class Trip {
    var name: String = ""                     // defaults keep migrations painless
    // ✅ Explicit delete rule + inverse, declared on ONE side only —
    // @Relationship on both sides creates a circular macro reference
    @Relationship(deleteRule: .cascade, inverse: \Stop.trip)
    var stops: [Stop]? = []
}
```

- Declare `@Relationship(deleteRule:inverse:)` explicitly — the implicit default (`.nullify`, inferred inverse) hides data-integrity decisions. Put the macro on **one** side; the other side is a plain property.
- A property named `description` is **disallowed** on `@Model` classes (NSObject collision) — rename.
- No `willSet`/`didSet` property observers on persisted properties — they don't fire reliably.
- Enums must be `Codable` to persist (associated values do work); `@Transient` properties need a default value.
- One `#Unique` constraint per model — combine key paths into a single `#Unique<T>([\.a, \.b])` rather than declaring two.
- `persistentModelID` is **temporary until the first save** — never store or compare IDs of unsaved models.

---

## Context Discipline

- **`@Query` belongs only inside SwiftUI views.** In services, use `ModelContext.fetch(_:)` / `fetchCount(_:)` with a `FetchDescriptor`.
- **Call `save()` explicitly** after meaningful mutations — autosave timing is not a contract. No `hasChanges` check needed; saving a clean context is cheap.
- **Models and `ModelContext` never cross actor boundaries.** Pass a `PersistentIdentifier` and re-fetch on the other side:

```swift
// ✅ Cross-actor handoff
let id = trip.persistentModelID
await backgroundImporter.process(id)   // the actor re-fetches via its own context

// ❌ Sending the model itself — data race / crash
await backgroundImporter.process(trip)
```

- Read-heavy fetches: set `relationshipKeyPathsForPrefetching` / `propertiesToFetch` on the `FetchDescriptor` to avoid N+1 faulting.
- Write a `ModelConfiguration(isStoredInMemoryOnly: true)` container for tests — same in-memory rule as Core Data (testing.md).
- Schema changes get an **explicit `VersionedSchema` + `SchemaMigrationPlan`** even when the migration is lightweight — implicit migration failures surface as launch crashes in the field.

---

## CloudKit-Backed Stores

If the SwiftData store syncs via CloudKit, these are hard requirements — violations fail at container init or sync silently:

- **Never** `@Attribute(.unique)` or `#Unique` — CloudKit cannot enforce uniqueness.
- Every property has a **default value or is optional**.
- Every relationship is **optional**.
- Design for eventual consistency: another device's changes arrive late and out of order — no logic may assume the local store is complete.

---

## Performance & Newer Features

- `#Index<Trip>([\.startDate], [\.name, \.startDate])` (iOS 18+) for read-heavy, frequently-filtered models; skip for write-heavy/logging tables — each index taxes every write.
- Model class inheritance exists in iOS 26+ (subclasses need `@available(iOS 26, *)`, all subclasses listed in the schema, `$0 is Subtype` predicate filtering) — it is rarely the right call; prefer protocols + composition.
