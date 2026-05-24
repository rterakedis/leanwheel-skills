# Runbook — {project_name}

Step-by-step procedures for recurring operations. Each section is self-contained — you should be able to follow it without context from other sections.

---

## Deploy

**When:** {describe the trigger — merge to main, manual, scheduled}

```bash
# Step 1: {description}
{command}

# Step 2: {description}
{command}
```

**Verify:** {what to check to confirm deploy succeeded}

---

## Rollback

**When:** Deploy caused errors or degraded behavior.

```bash
# Step 1: {description}
{command}
```

**Verify:** {what to check to confirm rollback succeeded}

---

## {Common Operation}

**When:** {when you'd run this}

```bash
{command}
```

**Expected output:** {what success looks like}
