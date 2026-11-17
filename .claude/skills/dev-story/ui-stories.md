# UI stories — read only when the story changes user-visible UI

Applied from Activation step 4c and On Completion step 2.

## Design contract (Activation step 4c)

- The story has a `### Design Contract` in Dev Notes → it is the design source of truth. Use its tokens, states, and reuse list; do not read `docs/ux/` again.
- No Design Contract, and `docs/ux/DESIGN.md` exists → read DESIGN.md frontmatter and the relevant EXPERIENCE.md sections before implementing. Note the gap in Completion Notes so `/create-story` improves next time.

## Design verification (On Completion step 2)

1. Execute **VERIFY** from `skills/design-verify/SKILL.md`: render the changed surfaces (simulator or dev server + screenshots) and compare against the Design Contract.
2. Write results to `### Design Verification` in the story file. Unresolved mismatches stay in that section; the reviewer turns them into findings.
3. No rendering tooling available → record the manual checklist and continue.
