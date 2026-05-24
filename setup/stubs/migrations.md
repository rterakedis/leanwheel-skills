# Migrations — {project_name}

How to run database migrations and a log of what each migration changed.

## How to Run

**Apply all pending migrations:**
```bash
{migration run command}
```

**Check migration status:**
```bash
{migration status command}
```

**Roll back the last migration:**
```bash
{migration rollback command}
```

**Create a new migration:**
```bash
{migration create command} -- {description}
```

## Migration Log

| # | Name | Date | What changed |
|---|------|------|-------------|
| 001 | {name} | {date} | Initial schema — created {tables} |

---

## Conventions

- Migration names: `{NNN}_{verb}_{noun}` — e.g. `002_add_users_email_index`
- Each migration must be reversible unless reversal is genuinely impossible (note why in the log)
- Never edit an existing migration — create a new one instead
