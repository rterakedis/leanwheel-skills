---
name: swift-audit
description: Audit planning docs, story files, and Swift source code against the Swift/SwiftUI guidance in docs/setup/swift/. Produces a remediation story file with one AC per finding. Use when the user says "swift audit", "audit swift", "audit codebase", or "check swift patterns".
---

# Swift Audit Skill

**Goal:** Scan the entire project — planning docs, story files, and Swift source code — against the guidance in `docs/setup/swift/`. Collate all findings into a single remediation story file that `/dev-story` can implement directly.

**Requires:** `docs/setup/swift/` must exist. If absent, tell the user to run `/setup` (for a new project) or `/refresh-swift` (to populate an existing project's swift docs).

---

## Step 1 — Load Guidance

Read all files present in `docs/setup/swift/`:

```bash
ls docs/setup/swift/
```

Read each file completely. These are the standards everything will be measured against. Pay particular attention to `anti-patterns.md` — it contains the hard rejection list used for code scanning.

---

## Step 2 — Inventory the Project

Run these commands to understand what exists:

```bash
# Planning docs
ls docs/prd.md docs/architecture.md docs/epics.md 2>/dev/null

# Story files
find docs/epics -name "*.md" | sort

# Swift source files (exclude build artifacts and dependencies)
find . -name "*.swift" \
  ! -path "*/DerivedData/*" \
  ! -path "*/.build/*" \
  ! -path "*/Pods/*" \
  ! -path "*/Packages/*" \
  | sort

# Existing audit files (to avoid re-auditing completed work)
find docs/epics -name "swift-audit-*.md" | sort
```

Note what is present. If no Swift source files exist yet, skip Step 4 and note "no source to audit" in the report.

---

## Step 3 — Audit Planning Docs

Read each planning doc that exists and reason against the guidance. For each doc, look for:

### `docs/architecture.md`

| What to check | Rejection signal |
|---|---|
| Data layer / state management design | References MVVM, ViewModel classes, `ObservableObject`, `@Published` as the prescribed pattern |
| Dependency injection / service access | Prescribes init-parameter injection of services instead of `@Environment` |
| Concurrency / threading design | Prescribes `DispatchQueue`, `OperationQueue`, or Combine pipelines for new code |
| Project structure | Type-based structure (`/Models`, `/Views`, `/Services`) rather than feature-based |
| Navigation design | References `NavigationView` (deprecated) |
| Testing strategy | Prescribes XCTest classes rather than Swift Testing |
| iPadOS navigation (if applicable) | Prescribes `NavigationStack` alone as iPad root instead of `NavigationSplitView` |
| macOS settings (if applicable) | Prescribes a sheet or modal for app settings instead of `Settings` scene |

### `docs/prd.md`

| What to check | Rejection signal |
|---|---|
| Technical requirements or constraints | Mandates a specific architecture that conflicts with current guidance |
| Non-functional requirements | References threading or concurrency approaches that are now anti-patterns |

### `docs/epics.md`

| What to check | Rejection signal |
|---|---|
| Epic or story descriptions | Reference banned patterns in task or acceptance criteria language |
| Technical approach notes | Prescribe ViewModel files, Combine usage, or legacy observation in task descriptions |

### Story files (`docs/epics/*.md`, excluding `swift-audit-*.md`)

For each story file, check:
- Tasks that instruct creating `*ViewModel.swift` files
- Dev Notes that reference `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`
- Acceptance Criteria that imply a banned pattern ("the ViewModel must expose…")
- Dev Notes that prescribe `DispatchQueue` or `import Combine`

---

## Step 4 — Audit Swift Source Code

Run grep commands to find hard violations in `.swift` files. For each match, record the file path and line number.

```bash
# Banned observation patterns
grep -rn "ObservableObject\|@Published\|@StateObject\|@ObservedObject\|@EnvironmentObject" \
  --include="*.swift" \
  --exclude-dir="{DerivedData,.build,Pods,Packages}" .

# DispatchQueue in non-legacy files
grep -rn "DispatchQueue" \
  --include="*.swift" \
  --exclude-dir="{DerivedData,.build,Pods,Packages}" .

# Combine imports in new files
grep -rn "^import Combine" \
  --include="*.swift" \
  --exclude-dir="{DerivedData,.build,Pods,Packages}" .

# onAppear + Task leak pattern
grep -rn "onAppear" \
  --include="*.swift" \
  --exclude-dir="{DerivedData,.build,Pods,Packages}" . \
  | grep -v "// ✅"

# Deprecated NavigationView
grep -rn "NavigationView" \
  --include="*.swift" \
  --exclude-dir="{DerivedData,.build,Pods,Packages}" .

# ViewModel files
find . -name "*ViewModel.swift" \
  ! -path "*/DerivedData/*" \
  ! -path "*/.build/*" \
  ! -path "*/Pods/*" \
  ! -path "*/Packages/*"

# Array conversion of FetchedResults
grep -rn "Array(.*[Ff]etch" \
  --include="*.swift" \
  --exclude-dir="{DerivedData,.build,Pods,Packages}" .

# UIDevice idiom check (use size classes instead)
grep -rn "userInterfaceIdiom" \
  --include="*.swift" \
  --exclude-dir="{DerivedData,.build,Pods,Packages}" .

# Index-based ForEach on mutable data
grep -rn "ForEach(0\.\.<\|ForEach(.*\.indices" \
  --include="*.swift" \
  --exclude-dir="{DerivedData,.build,Pods,Packages}" .

# Old TabView pattern (tabItem without Tab wrapper)
grep -rn "\.tabItem" \
  --include="*.swift" \
  --exclude-dir="{DerivedData,.build,Pods,Packages}" .

# XCTest in new test files
grep -rn "^import XCTest\|XCTestCase" \
  --include="*.swift" \
  --exclude-dir="{DerivedData,.build,Pods,Packages}" .
```

**Design token compliance (if `docs/ux/DESIGN.md` exists):** read its frontmatter token block, then grep for hardcoded colors that bypass it:

```bash
# Hardcoded colors in views (should come from the design token layer / asset catalog)
grep -rn "Color(red:\|Color(hex:\|Color(#colorLiteral\|UIColor(red:" \
  --include="*.swift" \
  --exclude-dir="{DerivedData,.build,Pods,Packages}" .
```

Flag each hit where a DESIGN.md token covers the value (MEDIUM). Values with no corresponding token are a DESIGN.md gap finding rather than a code finding.

For each `onAppear` hit, read surrounding lines (±5) to determine if it contains a `Task {` — only flag if it does. For `DispatchQueue` hits, read surrounding lines to determine if the file is a legacy wrapper (acceptable) or new code (flagged). Use judgment — do not flag things that are clearly intentional compatibility shims with a comment explaining why.

---

## Step 5 — Triage Findings

Assign each finding a scope tag and severity:

**Scope tags:**
- `[DOC-ARCH]` — finding in `architecture.md`
- `[DOC-PRD]` — finding in `prd.md`
- `[DOC-EPICS]` — finding in `epics.md`
- `[STORY]` — finding in a story file
- `[CODE]` — finding in Swift source

**Severity:**
- `HIGH` — active anti-pattern that will produce wrong code when implemented (e.g., architecture prescribes `ObservableObject`; source file uses banned pattern in production path)
- `MEDIUM` — pattern that diverges from guidance but may not cause immediate breakage (e.g., `NavigationView` still compiles; XCTest still works)
- `LOW` — style or convention gap (e.g., type-based project structure that could be refactored; index-based `ForEach` on a list that currently never mutates)

Deduplicate: if the same file has five `@Published` properties, that is one finding with a note that multiple instances exist.

If zero findings across all scopes: skip Step 6, report "Clean — no violations found against current guidance." and stop.

---

## Step 6 — Write Remediation Story

Write to `docs/maintainer/swift-audit-{YYYY-MM-DD}.md`. Use today's date. Create `docs/maintainer/` if it does not exist.

### Story File Format

```markdown
---
Status: ready-for-dev
Type: remediation
Generated: {today's date}
---

# Swift Audit Remediation — {today's date}

**Source:** `/swift-audit` run against guidance in `docs/setup/swift/`
**Findings:** {N} total — {H} HIGH / {M} MEDIUM / {L} LOW

---

## Acceptance Criteria

<!-- DOC findings first, then CODE findings. HIGH severity first within each group. -->

### Planning Docs
- [ ] [HIGH][DOC-ARCH] {one-line description} — `docs/architecture.md`
- [ ] [MEDIUM][DOC-ARCH] {one-line description} — `docs/architecture.md`
- [ ] [MEDIUM][DOC-PRD] {one-line description} — `docs/prd.md`

### Story Files
- [ ] [MEDIUM][STORY] {one-line description} — `docs/epics/{filename}.md`

### Swift Source
- [ ] [HIGH][CODE] {one-line description} — `{File.swift}:{line}`
- [ ] [MEDIUM][CODE] {one-line description} — `{File.swift}:{line}`

---

## Tasks

### 1. Update Planning Docs
- [ ] Revise `architecture.md` to replace banned patterns with current guidance
- [ ] Revise `prd.md` where technical constraints conflict with current guidance
- [ ] Revise `epics.md` story/task language that references anti-patterns

### 2. Update Story Files
- [ ] Update story Dev Notes and task descriptions that prescribe banned patterns

### 3. Fix Swift Source
- [ ] Resolve all HIGH code findings before any MEDIUM/LOW
- [ ] Run the project's test suite after each batch of fixes to confirm no regressions

---

## Dev Notes

### Reference
Read all files in `docs/setup/swift/` before implementing any fix. The guidance files
are the source of truth for what each banned pattern should be replaced with.

### Finding Details

#### DOC-ARCH findings
{For each: what was found verbatim, file location, what it should say instead}

#### DOC-PRD findings
{same}

#### DOC-EPICS findings
{same}

#### STORY findings
{same — include story file name and the specific AC/task/Dev Note line}

#### CODE findings
{For each: file:line, the offending code snippet (1–3 lines), the replacement pattern from guidance}

### Notes
- Do not modify story files listed here if their Status is `in-progress` or `done` —
  log a separate note in Completion Notes instead.
- For CODE findings in files not yet implemented (stubs or placeholders), update the
  stub rather than writing the fix inline.
```

---

## Step 7 — Report to User

After writing the story file:

1. State the story file path.
2. Print the finding summary table:

| Scope | HIGH | MEDIUM | LOW | Total |
|---|---|---|---|---|
| DOC-ARCH | | | | |
| DOC-PRD | | | | |
| DOC-EPICS | | | | |
| STORY | | | | |
| CODE | | | | |

3. Say: "Run `/dev-story docs/maintainer/swift-audit-{date}.md` to implement all fixes."
