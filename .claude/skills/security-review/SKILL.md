---
name: security-review
description: Security audit against OWASP, SQL hardening, auth, secrets, dependencies, and LLM-specific threats. Use when the user says "security review", "security audit", or "security check". Also invoked as Pass D during code-review for security-sensitive stories.
---

# Security Review Skill

**Goal:** Find exploitable vulnerabilities, data exposure, anti-patterns before production. All findings auto-scheduled.

**Entry points:** `/security-review` (full or scoped, writes report) | Pass D (inline from code-review).

---

## Activation

**`/security-review`:** Full or scoped? (Full: run all checklists; Scoped: run relevant categories only).

**Pass D (inline):** Run categories from story's `Security Sensitivity:` field in Dev Notes.

---

## Security Sensitivity Flag

Stories/specs must include `Security Sensitivity:` in Dev Notes if touching: auth, data-access, api, secrets, llm, payments, file-upload.

Categories auto-set by `/create-story`. Pass D triggered by flag in `/dev-story`.

---

## Checklists

Run applicable categories. For each item, mark: **Pass**, **Fail** (with file:line citation), or **N/A**.

### Category: Injection (OWASP A03)

- [ ] All database queries use parameterized statements or ORM query builders — no string concatenation with user input
- [ ] No raw SQL strings built from request parameters, headers, or URL segments
- [ ] ORM methods that allow raw SQL (e.g., `.raw()`, `.query()`, `execute()`) are absent or reviewed for injection risk
- [ ] HTML output is escaped or uses a framework that auto-escapes (no `dangerouslySetInnerHTML`, `innerHTML =`, or template literal injection into DOM)
- [ ] Shell commands do not include user input; if unavoidable, input is validated against a strict allowlist
- [ ] XML/JSON parsers are not processing untrusted external schemas (XXE prevention)

### Category: Authentication & Session (OWASP A07)

- [ ] Passwords are hashed with bcrypt, argon2, or scrypt — never SHA/MD5, never plaintext
- [ ] JWT secrets are sufficiently long (≥256-bit) and loaded from env, not hardcoded
- [ ] JWTs are validated on every protected route — algorithm, expiry, signature
- [ ] JWT stored in httpOnly cookie or server-side session — not localStorage
- [ ] Refresh token rotation is implemented if refresh tokens are used
- [ ] Session fixation prevented — session ID regenerated on login
- [ ] Password reset tokens are single-use and expire within 1 hour
- [ ] Account enumeration prevented — registration and password reset return identical responses for existing/nonexistent accounts
- [ ] Auth endpoints have rate limiting

### Category: Access Control (OWASP A01)

- [ ] Every API endpoint verifies the authenticated user owns or has permission for the requested resource (no IDOR)
- [ ] Admin-only routes have role/permission checks, not just authentication checks
- [ ] Bulk operations (list, export) are scoped to the requesting user's data
- [ ] Deleted or inactive accounts cannot authenticate

### Category: Data Exposure (OWASP A02)

- [ ] API responses do not include fields the client doesn't need (no leaking internal IDs, hashes, or other users' data)
- [ ] PII is not logged (no email, name, IP, or user ID in application logs at info/debug level)
- [ ] Database connection strings, API keys, and secrets are not in source code or committed config files
- [ ] `.env` and credential files are in `.gitignore`
- [ ] Error responses return generic messages to clients — stack traces and internal paths are server-side only

### Category: API Hardening (OWASP A05)

- [ ] CORS origin is an explicit allowlist — `*` is not used in production config
- [ ] All mutating endpoints (POST/PUT/PATCH/DELETE) require authentication
- [ ] Request body size limits are configured
- [ ] Rate limiting is applied to auth, registration, password reset, and expensive endpoints
- [ ] HTTP security headers are set: `Content-Security-Policy`, `X-Frame-Options`, `X-Content-Type-Options`, `Strict-Transport-Security`

### Category: Secrets Management (OWASP A02)

- [ ] No hardcoded secrets, API keys, or credentials anywhere in the codebase (`grep -r "sk-\|api_key\|password\s*=" --include="*.{js,ts,py,go,rb}"`)
- [ ] All secrets loaded from environment variables or a secrets manager
- [ ] `.env.example` exists with placeholder values — `.env` is gitignored
- [ ] CI/CD secrets are stored in the platform's secret store, not in workflow YAML files

### Category: Dependencies (OWASP A06)

- [ ] `npm audit` / `pip audit` / `bundle audit` / equivalent shows no critical or high severity vulnerabilities
- [ ] Lockfile (`package-lock.json`, `poetry.lock`, etc.) is committed and up to date
- [ ] No packages with known abandoned maintenance or active CVEs

### Category: LLM Integration

*Skip if the project does not use an LLM API.*

- [ ] User-supplied input that is inserted into prompts is sanitized — delimiter injection prevented (e.g., user cannot close a system prompt block with `"""` or `###`)
- [ ] Prompt templates do not include secrets, internal system info, or other users' data
- [ ] PII is not sent to external LLM APIs without explicit user consent and a documented data processing agreement
- [ ] LLM output used in SQL queries, shell commands, or HTML rendering is validated and escaped before use — treat LLM output as untrusted user input
- [ ] LLM API calls have a timeout and a fallback — no unbounded waits
- [ ] LLM endpoints have rate limiting to prevent prompt-flooding attacks
- [ ] System prompt contents are not exposed to users (no debug mode that echoes the system prompt)
- [ ] Token/cost limits per user or session are enforced to prevent resource exhaustion

### Category: File Upload

*Skip if the project does not accept file uploads.*

- [ ] File type validated by content (magic bytes), not just extension or MIME header
- [ ] Uploaded files are stored outside the web root — not directly served from an upload path
- [ ] Filenames are sanitized or replaced with a generated ID before storage
- [ ] File size limits are enforced at the server — not just client-side
- [ ] Virus/malware scanning is in place or documented as a known gap

---

## Triage and Output

Normalize findings: critical (auth bypass, SQL injection, secret exposure), high (IDOR, rate limit gaps, PII in logs), medium (headers, CORS, session), low (best practices).

Write to `docs/security-review-{date}.md` with scope, categories checked, findings by severity.

**Call LOG-AND-SCHEDULE for critical/high findings. Medium/low in report only (unless user confirms).

Auto-patch one-line fixes (headers, .gitignore, escape calls). Mark resolved.

---

## Called by

Story has `Security Sensitivity:` → Pass D in dev-story.
Epic with auth/data-access/api → scoped sweep (manual).
After /discover (brownfield) → full sweep (recommended).
Before production → full sweep (manual).
After /quick-dev (sensitive areas) → Pass D inline.
