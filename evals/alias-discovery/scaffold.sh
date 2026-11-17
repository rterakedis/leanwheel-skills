#!/usr/bin/env bash
# Self-contained: seeds a decision log only (no PRD yet), so "draft the PRD from the decisions" is a natural ask.
# Runs only with `claude plugin eval --scaffold`.
set -euo pipefail
mkdir -p docs/project
cat > docs/project/decisions.md <<'EOF'
# Decision Log

## Destination
A PRD for a small invoicing app for freelancers.

## Decisions
- 2026-10-02 — iOS only, SwiftUI, iOS 18+ — why: target users are iPhone-first — source: /ideate
- 2026-10-02 — Single user, no accounts or sync in v1 — why: keeps scope to a weekend MVP — source: /ideate
- 2026-10-03 — Invoices are one-way: Draft to Sent, never edited after sending — why: legal record — source: /ideate

## Rejected
- 2026-10-03 — Multi-currency in v1 — why: complexity, no demand — source: /ideate

## Not yet specified

## Out of scope
- 2026-10-02 — Android — why: no capacity — source: /ideate
EOF
