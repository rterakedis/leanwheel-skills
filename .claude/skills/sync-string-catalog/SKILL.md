---
name: sync-string-catalog
description: Have the running Xcode rebuild this checkout so its String Catalog (.xcstrings) follows the code, then review the changed keys and commit the catalog on the branch. Use before a PR on an Apple project that touches user-facing strings, or when the user says "sync string catalog", "sync xcstrings", "catalog drift", or "localizable is stale". Called by /dev-story (Build & Test Gate) and /code-review (Verify green) as the CHECK op.
---

# Sync String Catalog

**Why this exists.** `xcodebuild` extracts strings but never merges them into an `.xcstrings`
catalog; only a build inside the Xcode IDE does. Agents only run `xcodebuild`, so a new key or
a translator-comment edit passes every gate and merges with a stale catalog. The drift surfaces
later as an unexplained diff in the main checkout. Mechanism and footguns:
`docs/setup/swift/xcode-footguns.md` → *A green `xcodebuild` leaves the String Catalog stale*
(project copy) and [reference.md](reference.md) (Xcode MCP notes).

**The script does the work; this skill decides.** `scripts/xcode-catalog-sync.py` drives
Xcode's MCP server (`xcrun mcpbridge`, Xcode 26.3+) to open **this checkout's** project — a
worktree, not `main` — build until the catalog stops changing, and diff each tracked catalog
against HEAD as parsed JSON. It never commits. Zero model tokens until its last line is read.

**Preconditions:** macOS, Xcode running with MCP enabled (Settings → Intelligence), and the
agent approved in Xcode's prompt on first use. Without them the script exits 2 — see CHECK.

---

## CHECK (composable — the gate)

Run from the checkout root. Zero tokens: read only the **last line** of stdout.

```bash
python3 scripts/xcode-catalog-sync.py --check 2>&1 | tee .leanwheel/logs/catalog-sync.log | tail -n 25
```

Map the exit code to the `CATALOG` report field (last stdout line is already in this form):

| Exit | Last line | Meaning | Gate outcome |
|---|---|---|---|
| 0 | `CATALOG: in-sync` | every tracked catalog matches HEAD after an Xcode build | pass |
| 0 | `CATALOG: none` | no git-tracked `*.xcstrings` — nothing can drift | `n/a` |
| 1 | `CATALOG: drift N catalog(s)` | Xcode rewrote a catalog; keys listed above the line | **not done** — run SYNC |
| 2 | `CATALOG: unavailable — {why}` | Xcode not running / MCP off / not approved / build failed / timeout | **blocked**, never a pass |

**Exit 2 is `blocked`, not green (DD-80).** Record `CATALOG: unavailable — {why}` verbatim in
the calling skill's report; under a flywheel it pauses like any environment fault. Tell the
user the one-line fix (open Xcode, enable MCP, approve the agent). A gate that cannot run has
not run — never record `in-sync` because the script could not be executed.

Skip CHECK entirely only when the project is not an Apple project, or `git ls-files
'*.xcstrings'` is empty — state which.

## SYNC (interactive — review, then commit on the branch)

1. Run CHECK (or re-use its output). On `in-sync` / `none`: report and stop.
2. On `drift`: read the per-catalog key list the script printed — `+` added, `-` removed,
   `~` changed (comment or value), or *key order only*. Every line must be explained by this
   branch's diff:
   - `+` a string the branch added · `-` one it removed or renamed · `~` a comment/value it edited.
   - **A `-` with no matching source change** means a key was hand-inserted or a call site was
     deleted — check before accepting: `localization.md` → *`extractionState: stale`*.
   - **Key order only:** a hand edit put keys out of Xcode's order. Accept — committing the
     re-sorted file is what stops the surprise diff later.
3. Commit the catalog **on the current branch** with the story's other changes, or as its own
   commit when the strings were already committed:
   `bash scripts/commit-push.sh "Sync String Catalog after Xcode build" {catalog paths}`.
   The script never commits; you do, after reading the list. Never hand-edit keys into the
   catalog to make the list go away — that is how the drift starts.
4. Re-run CHECK: it must now print `CATALOG: in-sync` (exit 0). Record that in the report.

## Report field (consumed by dev-story / code-review / ledger)

```
CATALOG: in-sync | drift-committed | unavailable — {why} | n/a
```

`drift-committed` means SYNC ran and the re-check was `in-sync`. A report that ends a Swift
story without this field is incomplete.

## Configuration

Nothing is hard-coded. Resolution order:

- **Project:** `--project PATH`, else `container` in `.leanwheel/sim.json` (written by
  `scripts/sim.sh`), else the first `*.xcworkspace` / `*.xcodeproj` within 3 levels.
- **Catalogs:** `--catalog PATH` (repeatable), else every git-tracked `*.xcstrings`.
- `--keep-open` leaves the project open in Xcode; `--timeout N` bounds one MCP reply (default
  900 s — the first open waits on the approval prompt).

Standalone invocation by the user: `/sync-string-catalog` → run SYNC.
