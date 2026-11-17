# Migration-shaped stories — read only when Dev Notes says `**Shape:** migration`, or the story's core is plainly a repeated mechanical change

A repeated mechanical change is a rename or type migration across N sites, a dependency swap, and the like — even if unlabeled.

**The invariant test is Task 1.** If the task list is ordered otherwise, reorder it.

1. Write the invariant test **before** the edits.
2. Run it and confirm it fails enumerating every violation.
3. Make the edits.
4. At the end, re-prove it: revert exactly one instance and confirm a failure that names that instance (DD-11).
