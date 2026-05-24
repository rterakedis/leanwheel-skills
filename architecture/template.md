# Architecture: {Project Name}

*Last updated: {date}*


## 1. Tech Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Language | | |
| Runtime | | |
| Frontend | | |
| Database | | |
| Auth | | |
| Hosting | | |
| Key services | | |

## 2. Data Model

### Core Entities
- **{Entity}** — {description}. Fields: {list}. Relates to: {other entities}.

### Relationships
- {Entity A} → {Entity B}: {cardinality and nature}

## 3. API / Integration Design

**Style:** {REST / GraphQL / tRPC / etc.}
**Auth mechanism:** {JWT / session / API key / etc.}
**Error contract:** {shape of error responses}

### Key Endpoints / Operations
- `{METHOD} {path}` — {purpose}. Request: `{shape}`. Response: `{shape}`.

### External Integrations
- **{Service}** — {how called, auth, failure behavior}

## 4. Project Structure

```
{project-root}/
  {annotated folder tree}
```

**Naming conventions:**
- Files: {convention}
- Components: {convention}
- Routes: {convention}

## 5. Key Patterns and Conventions

1. {Pattern/rule — be specific enough that a dev session can follow it without asking}
2. …

**Explicitly banned:**
- {Anti-pattern and why}

## 6. Security Model

*Decisions made here are enforced by `/security-review`. Leaving a field blank is a choice — document why.*

**Auth mechanism:** {JWT / session cookie / OAuth / API key — storage location, expiry, rotation policy}
**Password hashing:** {bcrypt / argon2 / scrypt — never SHA/MD5}
**Data classification:** {what is PII, what is sensitive, how is each stored and transmitted}
**LLM data policy:** {what user data (if any) is sent to external LLM APIs — none / anonymized / with consent}
**Secrets management:** {env vars / secrets manager — where secrets live, how they're injected}
**Rate limiting:** {which endpoints, what limits, what library/service}
**Known security gaps:** {anything intentionally deferred — document the gap and the plan}

## 7. Testing Strategy

| Scope | Tool | What's covered | CI gate? |
|-------|------|----------------|----------|
| Unit | | | |
| Integration | | | |
| E2E | | | |
