# Metrics — flywheel observability

Minimal, **zero-token** observability for the agentic loop. The paper makes
observability a first-class harness pillar ("without observability there is no way
to tell whether the agent is doing well or quietly drifting"). This folder is the
lightweight version of that: plain append-only files, no model calls.

## Files

- `flywheel-ledger.jsonl` — one curated line **per phase per story**, appended by
  `dev-story`, `code-review`, and `story-flywheel`. This is the signal you read.
- `activity.jsonl` — raw tool-call stream appended by the `log-activity.sh` hook
  (capped at 2000 lines). Backs the ledger; usually ignored unless debugging.

## Ledger line schema

```json
{
  "ts": "2026-06-15T18:30:00Z",
  "story": "3.2",
  "phase": "dev-story",          // create-story | dev-story | code-review | story-flywheel | epic-flywheel
  "model": "opus",               // normalized (lowercase, no claude- prefix, dots→dashes)
  "build_test": "green",         // green | manual-required | red | blocked | n/a — enum only
  "build_detail": "233/233",     // optional qualifier; never part of build_test
  "bt_iterations": 2,            // times the Build & Test Gate re-ran before green
  "evals": "12/12",              // command evals passed / total (or n/a)
  "findings": {"patched": 3, "decisions": 1, "deferred": 0},
  "rubric_gate": "PASS",         // PASS | FAIL | n/a — never qualified
  "invariants": "4/4",           // verified / total (or n/a)
  "duration_min": 14
}
```

**Always append via `scripts/ledger.sh` — never hand-write a line.** The script owns
this schema: it stamps the UTC timestamp, normalizes model names so `jq` grouping
works, rejects free-text statuses, caps `notes` at 300 chars, and enforces the
verify-green gate rule (`rubric_gate: PASS` with a red/blocked `build_test` is
refused). Field drift from hand-written lines is what makes a ledger unqueryable.
Run `scripts/ledger.sh` with no args for usage. Never read the whole file into the
model to update it. Readers (`/retrospective`) grep only the current epic's lines.
The file is rotated to `docs/metrics/releases/{version}-ledger.jsonl` by
`/epic-archive cut-release`, so it stays bounded per release.

## Reading the signal — drift indicators

Skim the ledger (or `/status`) for:

- **Rising `bt_iterations`** across stories → the model is struggling on this
  surface; consider routing dev-story to a stronger model, or the guidance stubs
  are stale (run `/refresh-swift` / `/refresh-web`).
- **Rising `findings.patched` / falling `rubric_gate`** → spec quality slipping;
  tighten ACs / Behavior Contracts in create-story.
- **`build_test: manual-required` recurring** → no toolchain wired; the regression
  net isn't actually running. Fix the toolchain.
- **Model vs. cost** → confirm cheap phases stayed on Sonnet/Haiku and only Swift
  dev-story used Opus (the intended routing).
