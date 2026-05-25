# Database — {project_name}

Overview of the database layer: how to connect, what tool manages it, and where the detail lives.

## Connection

| Environment | How to connect |
|-------------|---------------|
| Local dev | `{connection string or command}` |
| Staging | `{connection string or command}` |
| Production | `{connection string or command — no credentials here, see resources.md}` |

## Tooling

- **Database:** {e.g. PostgreSQL 15, SQLite, MongoDB}
- **ORM / query layer:** {e.g. Prisma, Drizzle, SQLAlchemy, none}
- **Migration tool:** {e.g. Flyway, Liquibase, Prisma Migrate, Alembic}

## Detail Files

- [schema.md](schema.md) — table/collection definitions, fields, relationships
- [migrations.md](migrations.md) — migration history and how to run them
