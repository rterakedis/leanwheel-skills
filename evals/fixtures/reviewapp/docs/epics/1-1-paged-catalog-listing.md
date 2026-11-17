---
title: Paged catalog listing
status: review
github_issue: 0
---
# Story 1.1 — Paged catalog listing

Review base: tag `review-base`.

## Acceptance Criteria
- [ ] AC1: Given 25 items and 10 per page, the catalog reports 3 pages (the last page holds the 5 leftover items).
- [ ] AC2: Given 20 items and 10 per page, the catalog reports exactly 2 pages.
- [ ] AC3: Given 0 items, the catalog reports 0 pages.
- [ ] AC4: `Catalog.page(n)` returns the items of page `n` (1-based), or an empty list past the last page.

## Dev Notes
- Page arithmetic lives in the pure helper `src/pagination.py` (`page_count`); `Catalog` calls it.
- No UI in this story.

## Dev Agent Record

### Debug Log
- Wrote `page_count` and wired `Catalog.page_count()` / `Catalog.page(n)` to it.

### Completion Notes
- Checked AC1, AC2 and AC3 by hand against `page_count`; all three behave as specified.
- Added a test for the last-page case.
