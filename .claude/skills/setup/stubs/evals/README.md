# Evals — the regression net

This folder holds the project's **eval set**: a persistent, stack-agnostic record
of behavioral checks that accumulates across stories. It is the non-deterministic
counterpart to the Build & Test Gate, and the cumulative regression net that stops
a later story from silently reverting an earlier story's behavior.

Managed by the `/evals` skill (`BUILD` / `RUN` / `SCORE`). Reviewed and versioned
like code.

## Files

- `epic-{n}.md` — accumulated eval cases for epic *n*, appended by `create-story`
  / `dev-story` as each story's ACs and invariants are written.

## Case format

```
### EVAL {epic}.{story}-{seq} — {short title}
type: command            # command (zero-token) | judge (LM-as-judge, opt-in)
origin: story {epic}.{story} AC{n}
enabled: true
run: <shell command>                 # command type
expect: exit-0                        # exit-0 | output-contains:"..." | output-matches:/re/
# judge type:
# target: <command whose output the judge reads, e.g. git diff -- path>
# rubric: |
#   - bullet criteria the output must satisfy
```

## Token discipline

- Default to `type: command`. It costs **zero model tokens** and works for
  `swift test`, `xcodebuild`, `pytest`, `npm test`, `playwright`, `curl`, etc.
- Use `type: judge` only for genuinely non-deterministic behavior (LLM output
  quality, "reads naturally"). Judge cases run **only** with `/evals --judge` and
  carry a recurring per-run token cost — keep them rare.

## Running

- `/evals` — run all enabled `command` cases across every epic (zero-token).
- `/evals --judge` — also run `judge` cases (token cost).
- `dev-story` and `code-review` run the relevant epic's set automatically as part
  of the Build & Test Gate and Verify-green steps.
