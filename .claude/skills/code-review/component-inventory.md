# Component inventory — read only when the diff introduced a new reusable UI component

Applied from Step 5 → *Update component inventory*. A reusable component is a view/element designed to be used in more than one place. One-off layout subviews don't qualify; only components future stories should reuse.

Append a row to `docs/ux/components-built.md` — create the file with this header if missing:

```markdown
# Components Built
*Auto-maintained by /code-review. /create-story injects this into UI stories — reuse these, never create near-duplicates.*

| Component | File | Purpose | Variants/Props |
|---|---|---|---|
```
