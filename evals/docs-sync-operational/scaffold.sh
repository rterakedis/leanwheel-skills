#!/usr/bin/env bash
# Self-contained fixture (no evals/fixtures dir): a tiny web service whose story 3-2 added an env var,
# a migration, a script and a Dockerfile change. docs/setup + docs/sql exist; docs/maintainer deliberately
# does NOT (the skill must stay silent for an absent area). docs/setup/swift/ holds a sentinel guidance file.
# Runs only with `claude plugin eval --scaffold`.
set -euo pipefail
mkdir -p docs/setup/swift docs/sql docs/epics src migrations scripts

cat > docs/epics/3-2-webhook-events.md <<'EOF'
---
epic: 3
story: 2
title: Webhook events
status: review
github_issue: 0
---

# Story 3.2: Webhook events

## Dev Agent Record

### Completion Notes
Inbound webhooks are verified with an HMAC secret and stored in a new table.

### File List
- `src/config.ts` — modified
- `.env.example` — modified
- `migrations/0007_add_webhook_events.sql` — created
- `scripts/replay-webhooks.sh` — created
- `Dockerfile` — modified
EOF

cat > src/config.ts <<'EOF'
export const config = {
  databaseUrl: process.env.DATABASE_URL!,
  webhookSigningSecret: process.env.WEBHOOK_SIGNING_SECRET!, // new in 3.2: HMAC secret for inbound webhooks
};
EOF
printf 'DATABASE_URL=postgres://localhost/app\nWEBHOOK_SIGNING_SECRET=\n' > .env.example
cat > migrations/0007_add_webhook_events.sql <<'EOF'
CREATE TABLE webhook_events (
  id BIGSERIAL PRIMARY KEY,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  signature TEXT NOT NULL,
  payload JSONB NOT NULL,
  processed BOOLEAN NOT NULL DEFAULT false
);
CREATE INDEX webhook_events_unprocessed ON webhook_events (received_at) WHERE processed = false;
EOF
cat > scripts/replay-webhooks.sh <<'EOF'
#!/usr/bin/env bash
# Usage: scripts/replay-webhooks.sh [--since ISO8601]
# Re-queues every unprocessed row in webhook_events for processing.
set -euo pipefail
psql "$DATABASE_URL" -c "UPDATE webhook_events SET processed = false WHERE received_at >= coalesce('${2:-1970-01-01}'::timestamptz, 'epoch')"
EOF
cat > Dockerfile <<'EOF'
FROM node:22-slim
WORKDIR /app
COPY . .
RUN npm ci --omit=dev
ENV PORT=8080
EXPOSE 8080
CMD ["node", "dist/server.js"]
EOF

cat > docs/setup/index.md <<'EOF'
# Setup

## Prerequisites
- Node 22, Postgres 16

## Environment
Copy `.env.example` to `.env` and fill in:
- `DATABASE_URL` — Postgres connection string

External services and keys: see [resources.md](resources.md). Helper scripts: [scripts.md](scripts.md).

## Database
Run the migrations in order; see [../sql/migrations.md](../sql/migrations.md).
EOF
cat > docs/setup/resources.md <<'EOF'
# Resources

| Name | Kind | Where it is used |
|---|---|---|
| `DATABASE_URL` | env var | Postgres connection (`src/config.ts`) |
EOF
cat > docs/setup/scripts.md <<'EOF'
# Scripts

- `scripts/migrate.sh` — applies pending migrations.
EOF
cat > docs/sql/index.md <<'EOF'
# Database

- [migrations.md](migrations.md) — the ordered migration list
- [schema.md](schema.md) — tables and columns
EOF
cat > docs/sql/migrations.md <<'EOF'
# Migrations

| File | Purpose |
|---|---|
| `0006_add_users.sql` | creates `users` |
EOF
cat > docs/sql/schema.md <<'EOF'
# Schema

## users
`id`, `email`, `created_at`
EOF
cat > docs/setup/swift/concurrency.md <<'EOF'
<!-- fixture-sentinel-concurrency-v1 -->
# Concurrency guidance (externally sourced — owned by /refresh-swift)

Prefer `@MainActor` isolation for view models.
EOF
