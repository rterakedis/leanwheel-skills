# Localization — Gotchas and House Style

<!-- FIELD: predominantly trial-and-error knowledge from shipping projects. Protected from
     research-driven rewrites — see PROVENANCE.md before editing. -->

Every user-facing string goes through the String Catalog with a translator `comment:`. That
much is conventional. What follows is the part that silently *doesn't* localize, plus the
economics that decide how strings should be worded in the first place.

---

## Strings that silently bypass localization

<!-- FIELD: each of these renders correctly in English and is invisible until a second locale exists -->

### Nil-coalesced fallbacks

```swift
// ❌ "Not set" is never localized — and English looks perfect, so nothing reveals it
Text(customer.name ?? "Not set")

// ✅
Text(customer.name ?? String(localized: "Not set", comment: "Placeholder when a customer has no name"))
```

The mechanism: `Text` has an initializer taking `LocalizedStringKey` and one taking `String`.
A literal alone resolves to `LocalizedStringKey` and is looked up. Inside a `??` the expression's
type is driven by the optional's type — `String?` — so the whole expression is a plain `String`
and the lookup never happens. The string is also never extracted into the catalog, so it doesn't
even appear as an untranslated key.

The same applies to **any computed `String` property** whose value lands in a `Text`, a
`Button` label, or a `navigationTitle`. If a `String` is being built in Swift and shown to a
user, it must be built from `String(localized:)` pieces.

### Integers interpolated into a localized string get locale grouping

```swift
// ❌ Renders "Tax year 2,026"
Text(String(localized: "Tax year \(year)", comment: "…"))

// ✅ Years, IDs, version numbers, and anything that is a label rather than a quantity
Text(verbatim: "Tax year ") + Text(verbatim: String(year))
// or format explicitly:
Text(String(localized: "Tax year \(year, format: .number.grouping(.never))", comment: "…"))
```

An `Int` interpolated into a format string is formatted as a **number**, which means thousands
separators. Correct for a count, wrong for a year, an invoice number, or an ID.

---

## House style — because each unique source string is a paid translation unit

The String Catalog's economics are the reason to have a style at all: a near-duplicate is not a
cosmetic inconsistency, it is a second thing to translate into every locale, forever. Decide
these once and hold them.

- **One separator glyph between peer items.** Pick one (`/` reads well and types easily) and use
  it everywhere: `"\(count) / \(amount) unbilled"`. A decorative divider rendered alone should be
  `Text(verbatim: "/")` so a lone glyph isn't extracted as a translatable key.
- **Optional / parenthetical annotations use parentheses** — `"Email (optional)"`, not
  `"Email — optional"` in one place and `"Email · optional"` in another.
- **Where the separator would collide with a domain meaning** (rates like `$149/yr`), use
  parentheses instead: `"Annual ($149/yr)"`.
- **Title-case UI labels consistently** — field labels, section headers, picker options. Reserve
  sentence case for full sentences: validation messages, body copy, message templates.
- **Parameterize numeric option sets.** `ForEach([7, 14, 30, 60]) { Text("\($0) days") }` yields
  **one** `"%lld days"` catalog entry. Four hardcoded strings yield four.
- **Intentional context-specific casing is exempt** and should be commented as such — an all-caps
  `"ESTIMATE"` document header is a print convention, deliberately separate from the app's
  `"Estimate"` label.

---

## Translator comments are load-bearing

Every entry needs a non-empty comment answering: *where does this appear and what does it do?*
A translator sees the string and the comment, and nothing else — "Button" and "Label" are worth
less than an empty comment because they look like someone did the work.

| ❌ | ✅ |
|---|---|
| `"Button"` | `"CTA on the welcome screen that begins onboarding"` |
| `""` | `"Error banner title shown when iCloud storage is full"` |
| `"Label"` | `"Section header in Settings for business profile fields"` |

Pin it: a test that parses the catalog JSON and fails on any empty comment or duplicate key.
A lint rule that flags bare `Text("…")` without `comment:` in the view directories catches the
other half at authoring time.

---

## `extractionState: stale` — diagnose before deleting

A catalog entry marked stale ("References to this key could not be found in source code") means
the build's extraction pass found no call site. That is usually correct and the entry can go.

But check whether the string **moved rather than died**: a string that was reworded, or that
moved into a `String(localized:)` built at runtime, or that is now only reachable through a
generated symbol, is still needed and will render as its raw key if you delete it. The failure
is silent and locale-specific — English still looks right, because the key *is* the English
string.

---

## Two mechanical notes

- **Catalog tests read the source JSON, not the bundle.** `Localizable.xcstrings` compiles to a
  binary form that is not readable as JSON at runtime, so an integrity test must reach the
  source file via the `#file` compile-time path. Consequence: such tests only pass on a machine
  that compiled them, and break if the project moves. Acceptable locally; worth knowing before
  wiring them into CI.
- **Format strings with a `specifier:` generate an internal key** the catalog cannot predict. The
  entry is best-effort; the fallback is key-as-value, so the source locale still displays
  correctly. Don't chase it as a bug.
