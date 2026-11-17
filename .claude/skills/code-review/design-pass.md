# Pass E: Design Compliance — read only when the diff touches user-visible UI and `docs/ux/DESIGN.md` or a `### Design Contract` exists

Applied from Step 3. Inputs: the DESIGN.md frontmatter token block and the story's `### Design Contract` (loaded in Step 2). Every item below is a finding when it fails.

## Tokens, states, platform

- Hardcoded colors/spacing/type values where a DESIGN.md token exists (near-miss hex counts)
- Required states from EXPERIENCE.md missing: empty, loading, error, offline
- Dark mode: load-bearing surfaces missing the second appearance
- Platform checklist: Apple — tap targets, Dynamic Type, safe areas, SF Symbols; web — semantic elements, focus visibility, `alt`, heading hierarchy, off-token `!important`/inline styles
- New component that near-duplicates one in `docs/ux/components-built.md`
- Unresolved findings in the story's `### Design Verification` section
- **Never accept "the string/control is in the source" as evidence a UI change is reachable** — presence ≠ renders; require rendered evidence (see `dev-story` verification step).

## Automation contract (Apple projects with `docs/setup/swift/testability.md`)

Skip on projects without the testability foundation — route those to `/swift-audit` instead of filing per-diff findings.

- An interactive element or dynamic list row shipped with **no** `.accessibilityIdentifier`.
- An identifier that **differs from the name the story's Design Contract assigned** — HIGH: a silently renamed identifier breaks every flow, eval, and screenshot addressing it, and the break surfaces later as a red test in someone else's story.
- An identifier not matching `{feature}-{element}-{role}` kebab-case — MEDIUM.
- A **new screen with no deep-link route** — MEDIUM: unreachable by `/design-verify` and by every future flow.

## Dark patterns

Check the diff against EXPERIENCE.md's `## Engagement & Persuasion`, if present:

- pre-checked paid or consent opt-ins;
- smart defaults that pre-select the higher-cost/higher-commitment choice;
- fake or endowed progress indicators;
- countdown/urgency with no real deadline;
- guilt-decline (confirmshaming) copy;
- decoy pricing.

Flag any lever in the diff that isn't backed by an honest entry in that section — shipping user-hostile behavior is HIGH severity (it erodes trust and is a support/churn liability, not just a style nit).
