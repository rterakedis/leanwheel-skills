## Simplicity & Anti-Over-Engineering

> Updated: 2026-07-22

The reflex that fires **after** you understand the problem and have traced the real flow — never instead of that. Once you know what the code must do, reach for the least code that does it.

### The Laziness Ladder — stop at the first rung that holds

1. **Does this need to exist at all?** (YAGNI) — the best code is no code. Delete the requirement before writing the feature.
2. **Already in this codebase?** — reuse the existing helper/pattern/component; don't rewrite it.
3. **Standard library does it?** — reach for stdlib before hand-rolling.
4. **Native platform feature?** — the OS/framework/runtime already ships it; use it before adding code.
5. **Already-installed dependency does it?** — use what's on the manifest before adding a new one.
6. **One line?** — if a one-liner is correct and clear, stop there.
7. **Minimum code that works** — only now, write the smallest thing that satisfies the requirement.

### Rules

- No unrequested abstractions: no interface with one implementation, no factory for one product, no config option for a value that never changes.
- No boilerplate "for later" — build for today's requirement, not an imagined one.
- Deletion over addition: removing code is a valid, preferred change.
- Prefer stdlib / native platform features over a new dependency.
- Bug fix = root cause at the shared function, not a per-caller symptom patch.

### Not lazy about

Never simplify these away — laziness stops at the trust boundary:
- Understanding the problem first (the ladder runs *after* this).
- Input validation at trust boundaries.
- Error handling that prevents data loss.
- Security, accessibility, and anything the user explicitly requested.

### Deliberate corner-cuts — the `leanwheel:` marker

When you knowingly cut a real corner with a known ceiling, mark it inline so it can't rot silently:

```
// leanwheel: <ceiling>, <upgrade trigger>
```

e.g. `// leanwheel: O(n²) scan, index if list exceeds ~1k`. Comment-prefix agnostic (`//`, `#`, `--`). `/retrospective` harvests these markers and schedules the ones that name a real ceiling.
