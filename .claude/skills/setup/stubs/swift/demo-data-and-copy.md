# Demo Data & Product Copy — Two Ways to Ship a Liability

<!-- FIELD: both sections are trial-and-error rules from shipping apps; see PROVENANCE.md -->

Neither of these is caught by a compiler, a linter, or a code review that is looking at logic.
Both ship quietly and are expensive to unship.

---

## Seed & demo data: look real, resolve to nobody

Screenshot fixtures, `#Preview` mock data, and onboarding sample records must look like a
genuine dataset — an app demoed with `Test Customer 1` looks broken. Realism is not what gives
way. The **identifiers** are.

**A seeded record may never be resolvable to a real person, home, or company.**

### `#if DEBUG` is not the control

The tempting argument is that fixtures never ship, so it doesn't matter. It does: preview and
seed data gets pasted into documentation, decks, App Store screenshots, marketing pages, and
bug reports. The blast radius is everywhere the data is *shown*, which is not gated by a
compilation flag. Assume every seeded value will end up in a public image.

### Reserved ranges — use them, they exist for this

| Field | Reserved range | Never |
|---|---|---|
| Phone | `555-01xx` (with any real area code) — the only block reserved for fiction | Any other prefix. It is dialable, and it reaches someone. |
| Personal email | `@example.com` / `example.net` / `example.org` (RFC 2606) | A real provider — the local part plausibly belongs to someone at `gmail.com`. |
| Business/org email | a `.example` TLD (RFC 2606) | A registrable domain, especially one derived from the fictional business name — you are inventing a domain someone can buy. |
| URLs | `example.com` | Any domain you have not checked. |

### Names and streets have no reserved range — so search every one, individually

**Do not reason about whether a coined name is real. Search it.** On one project, a sweep of a
freshly-coined address table found roughly **one name in three was a real street in the target
city**.

The reason is structural, not carelessness: the English-pastoral register that reads as a
plausible subdivision (`Wren-`, `Ash-`, `-brook`, `-moor`, `-croft`, `-grove`) is exactly the
register real developers draw from. "Invent a plausible street name" and "guess a real street
name" are the same algorithm. Coinages *outside* that register survive verification far more
often.

- **Addresses:** keep real neighborhood coordinates and ZIPs if map or routing math depends on
  them, but **invent the street name** so the full triple is not deliverable. Maintain a
  banned-stems list of every name that came back real, and pin it with a test.
- **Company / organization names:** search before committing one, every time. Organizations
  carry reputational risk on top of privacy risk. **No churches or named institutions** — high
  collision rate with real bodies. A third-party **brand** implies an association nobody
  granted. Generic payees (`City Utilities`) name a *kind* of vendor and are fine.
- **"Verified by the owner" in a story doc is not verification.** A record that a check was done
  is not the check. Run the search yourself and cite it.

### Two more that are easy to miss

- **Never seed a live payment handle** — a payment address, wallet, or `$cashtag` is the one
  field that routes real money to a stranger.
- **Free-text notes carry more than they look like.** A gate code, or `"Aggressive dog on
  Tuesdays"`, is harmless against a fictional address and safety-relevant against a real one.

### Pin it with a test

Fixture data is where privacy rules rot, because a fixture is edited casually. Assert that
every seeded phone is in `555-01xx`, every email is in a reserved domain, and no street stem
appears in the banned list. Assert a **lower bound on the number of records scanned**, or the
test passes vacuously the day the fixtures move.

**Author fixtures in one place.** If a UI test or a capture script hand-writes its own records,
those sit outside the pinning test — which is exactly how real street names re-enter after a
cleanup. A black-box UI-test target that cannot import the fixture module should duplicate a
single **already-vetted** constant as a literal, with a comment saying why, and coin nothing new.

---

## Regulated and consequential copy: name the purpose, never claim the status

Applies to any surface where the user might act on the app's output as though it were
authoritative — tax and financial records, health and fitness figures, legal or compliance
documents, safety information, professional-grade measurements.

**Describing what the feature is for is fine and wanted.** What is banned is any claim of
**status, conformance, or completeness**.

| ✅ Names the purpose | ❌ Claims a status |
|---|---|
| "a mileage log you can hand to your accountant" | "IRS-ready", "tax-ready", "audit-proof" |
| "tracks the figures your filing needs" | "meets Publication 463", "compliant with §…" |
| "an export your bookkeeper can work from" | "accurate and sufficient for filing" |

Three failure modes that are subtler than the obvious ones:

- **Never let copy imply completeness.** A screen called "Items to Check" surfaces what the app
  *noticed*. The copy must say outright that an unlisted item has not been checked by anyone —
  silence otherwise reads as "we QA'd the rest", which is a warranty by implication.
- **Never let a provenance label read as verification.** "Manual" records *who supplied* a
  number. It does not mean anyone checked it, and a label that reads as a checkmark is worse
  than no label.
- **An exported document may define its own vocabulary** (a cover-page method legend, a units
  note) but must never mark individual rows as suspect. Drive correction **before** the document
  exists; a document that flags its own contents as unreliable is not usable for the purpose it
  was made for.

This is a legal exposure, not a style preference — which is why it earns a tripwire in the
project's always-loaded rules even when the detailed statement lives next to the code.
