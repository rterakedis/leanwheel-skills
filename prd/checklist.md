# PRD Quality Checklist

Rate each dimension: **strong / adequate / thin / broken**. Only write findings where they add information.

## 1. Decision-readiness
Can a decision-maker act on this? Trade-offs surfaced honestly? Open Questions actually open?
- Red flag: every choice "balances" everything; no tension acknowledged.

## 2. Substance over theater
Is content earned or furniture?
- Persona theater: personas that don't drive a single FR decision
- NFR theater: boilerplate "must be scalable/secure" without product-specific thresholds
- Vision theater: statement that swaps into any PRD in this category unchanged

## 3. Strategic coherence
Does the PRD have a thesis? Do features serve a unified arc or is it a capability list?
- Success Metrics validate the thesis, not just measure activity

## 4. Done-ness clarity
Would an engineer know what "done" looks like for each FR?
- Every FR has at least one testable, verifiable consequence
- No adjectives ("graceful," "reasonable," "user-friendly") without a bound

## 5. Scope honesty
Are omissions explicit?
- Non-Goals do real work
- `[ASSUMPTION]` tags on all inferences; indexed in §9
- Deferred decisions noted with owner, not silently absent

## 6. Downstream usability
Can UX/architecture/story creation source-extract cleanly?
- Glossary present; no synonym drift across FRs, UJs, SMs
- FR/UJ/SM IDs contiguous and cross-references resolve
- Each UJ has a named protagonist

## 7. Shape fit
Has the PRD been forced into the wrong shape?
- Consumer/multi-stakeholder → UJs with named personas are load-bearing
- Internal/single-operator → capability spec; UJs may be overhead
- Hobby/solo → rigor light; substance bar still applies
