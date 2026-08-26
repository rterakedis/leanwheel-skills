# Provenance — research knowledge vs. field knowledge

Two different kinds of claim live in `docs/setup/swift/`, and they age differently:

| Kind | Where it came from | How it ages |
|---|---|---|
| **Research knowledge** | Apple docs, WWDC sessions, release notes, curated gold-standard authors. Refreshed by `/refresh-swift` against primary sources. | Goes stale on the OS/Xcode cadence. A newer source supersedes it outright. |
| **Field knowledge** | Trial and error on a real shipping project — a mechanism observed, a symptom paid for, a fix verified by running. Often *absent* from any primary source. | Does **not** go stale on a version bump. It only retires when a source shows the mechanism itself changed. |

Field knowledge is the expensive kind. It is typically what a primary source does not say:
that `isHittable` returns true for a tap the bar will eat, that a fresh simulator's missing
TCC grants look exactly like a wedged toolchain, that a green-looking log can be missing an
entire target. Losing one of those to a research pass costs the sessions it took to find.

---

## The marker

A field-earned rule carries an HTML comment immediately after its heading:

```markdown
### `isHittable` lies under translucent bars

<!-- FIELD: observed on a shipping iOS 26 app; three sessions misdiagnosed as a timing flake -->
```

The comment is invisible when rendered and greppable when not:

```bash
grep -rn "<!-- FIELD" docs/setup/swift/
```

A whole file that is field-derived carries the marker once, under its H1, instead of on every
section.

---

## The rule for `/refresh-swift` (and any other automated update)

A `<!-- FIELD -->` block is **protected**. A refresh pass may:

- ✅ **Append** a dated note beside it (`<!-- verified still current 2026-11-02 -->`).
- ✅ **Version-scope** it — narrow "on iOS 26" to "on iOS 26 through 26.x" — when a cited
  source establishes the range.
- ✅ **Retire** it, by moving it to a *Retired* section with the citation that shows the
  mechanism no longer exists, and saying so in the refresh report.
- ❌ **Never silently rewrite or delete it** because newer guidance covers the same topic.
  Newer *general* guidance does not contradict a specific observed failure.

The test for retirement is the **mechanism**, not the topic. "Apple's current docs recommend X"
does not retire a rule about what happens when X is used near a translucent bar. "The bar is
no longer translucent as of iOS 28, per <release note>" does.

When a refresh pass wants to change a field rule and cannot meet that bar, it **surfaces the
conflict in its report** rather than deciding — the person who paid for the rule is the one who
gets to retire it.

---

## Adding a field rule

Whenever a retrospective, a code review, or a debugging session produces a rule that a primary
source would not have told you, promote it here with:

1. The **mechanism** — what actually happens, at the level of "the tap is delivered to the bar".
2. The **symptom** — what you see first, including what it *looks* like ("hangs at 0% CPU with a
   stale log, indistinguishable from a toolchain wedge"). This is what makes the rule findable
   the next time someone hits it.
3. The **fix**, concretely.

Drop the project-specific anecdote — the story number, the entity name, the internal ticket id.
Keep the mechanism and the symptom; those are what generalize.
