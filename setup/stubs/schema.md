# Schema — {project_name}

Table and collection definitions. Keep this in sync with the actual database — update it whenever a migration changes the schema.

*Last updated: {date}*

---

## {TableName}

**Purpose:** {what this table stores and why it exists}

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | {type} | No | — | Primary key |
| `{column}` | {type} | {Yes/No} | {value/—} | {description} |

**Indexes:**
- `{index_name}` on `({columns})` — {why this index exists}

**Relationships:**
- `{column}` → `{other_table}.{column}` ({one-to-many / many-to-many / etc.})

---

## {TableName}

*(repeat for each table/collection)*
