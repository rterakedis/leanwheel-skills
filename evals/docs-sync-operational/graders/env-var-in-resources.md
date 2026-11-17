---
type: regex
target: { source: file, path: docs/setup/resources.md }
pattern: "WEBHOOK_SIGNING_SECRET"
match: contains
---
The new env var is documented in `docs/setup/resources.md` (Env/config signal → resources.md). The fixture starts with only `DATABASE_URL` there.
