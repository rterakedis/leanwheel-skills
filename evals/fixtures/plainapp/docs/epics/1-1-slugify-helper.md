---
title: Slugify helper
status: ready-for-dev
github_issue: 0
---
# Story 1.1 — Slugify helper

## Acceptance Criteria
- [ ] Given a title with punctuation and mixed case, when `slugify` runs, then it returns lowercase words joined by single hyphens with no leading or trailing hyphen.

## Tasks
- [ ] Task 1: Add `slugify` to `lib/slugify.sh`
- [ ] Task 2: Cover it in `test/slugify_test.sh`

## Dev Notes
- Shell library only: no user-visible UI, no screens.
- One new function plus its test. Not a migration or a repeated mechanical change.
