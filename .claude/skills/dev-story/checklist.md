# Definition of Done Checklist

All items must pass before status is set to `review`.

## Implementation
- [ ] Every task and subtask is checked `[x]`
- [ ] Every AC is satisfied — can trace each AC to specific code
- [ ] No placeholder code, TODOs, or stubbed implementations left
- [ ] Edge cases from Dev Notes are handled
- [ ] Behavior Contract invariants (if any) verified with cited evidence — test or assertion/guard at `file:line` (not a prose claim)
- [ ] Touched files respect the decomposition targets in `docs/setup/swift|web/` guidance (if present) — over-target files are split by responsibility, or carry a one-line cohesion justification
- [ ] Only dependencies listed in Dev Notes or CLAUDE.md were used

## Build & Tests
- [ ] Project **builds clean this session** by actually running the toolchain (`xcodebuild … build` / `swift build` / `npm run build` / documented command) — not asserted from reading. Cite the command in the Debug Log, or record `Build & Test Gate: manual-required` if no toolchain exists.
- [ ] Unit tests written/updated for all changed logic
- [ ] Integration tests written/updated where Dev Notes require them
- [ ] Test suite **executed this session and green** (no regressions) — cite the run; a passing build is not a passing test suite
- [ ] Test framework and patterns from Dev Notes followed

## Story File
- [ ] File List includes every file created, modified, or deleted
- [ ] Completion Notes summarize key implementation decisions
- [ ] Change Log updated with one-line summary
- [ ] Only permitted sections were modified (Tasks, Dev Agent Record, File List, Change Log, Status)

## Final
- [ ] Status set to `review`
- [ ] No HALT conditions left unresolved
