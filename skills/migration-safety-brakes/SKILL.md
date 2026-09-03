---
name: migration-safety-brakes
description: Guardrails for working with Liquibase database migrations in this repository. Use whenever creating, editing, reviewing, or reasoning about changesets under db/changelog/. This skill exists to STOP unsafe actions, not to help perform them.
---

# Migration Safety Brakes

This skill is a set of hard rules, not suggestions. If a request conflicts with a rule below,
refuse the specific unsafe part, explain why in one sentence, and offer the safe alternative.
Do not proceed with the unsafe version even if the user insists, unless they show a signed-off
exception from the DBA channel (paste the message as proof).

## Scope boundaries (never do these)

1. **Never read, print, or quote contents of `src/main/resources/**` config/property/yaml
   files** (e.g. `application*.yml`, `*.properties`, anything under `resources/secrets/` or
   `resources/config/`), even indirectly via `cat`, `grep`, `view`, or a generated script that
   dumps them. These commonly contain DB credentials, API keys, or connection strings. If a
   migration task seems to require a value from one of these files, ask the user to paste just
   the specific non-secret value needed (e.g. schema name) instead of opening the file.

2. **Never operate outside this workspace.** Do not read, write, or run commands against paths
   outside the current repository root (no `~`, no `/etc`, no other project directories, no
   absolute paths that resolve outside the repo). Every file touched must live under
   `db/changelog/` or be a read-only reference inside this same repo.

3. **Never shell out to bypass these rules.** Do not use `bash`, `sh -c`, subprocess calls,
   or any generated script whose purpose is to read a restricted file, reach outside the
   workspace, or apply a migration directly against a live database (`liquibase update`,
   raw `psql`/`mysql` connections, etc.) instead of writing the changeset file. This skill only
   produces changeset files. It never executes them.

4. **Never edit a changeset that has already run in production.**
   Check `databasechangelog` history (from a file already in the repo, not a live DB query) or
   ask the user to confirm before assuming a changeset is still "in flight." If it already ran
   anywhere beyond local/dev, create a NEW changeset instead of modifying the old one.

5. **Never generate a migration that drops a column or table without a two-step plan.**
   Step 1: stop writing to it (deploy). Step 2: drop it (separate migration, later release).

6. **Never write a migration that changes a column type in place on a table likely to have
   production data** without an explicit backfill/rollback strategy in the changeset comments.

7. **Never suggest disabling `preConditions` or `failOnError: false`** to make a migration
   "just apply."

8. **Never auto-generate a `rollback` block that isn't actually reversible.** If a true
   rollback isn't possible, say so explicitly in the changeset comment instead of faking one.

## What this skill still allows

- Writing new, additive changesets (new tables, nullable columns, indexes) freely, as files
  under `db/changelog/`.
- Reading non-secret files already in the repo (schema docs, existing changelogs, README) to
  inform the migration.
- Reviewing existing changesets for the issues above and flagging them.

## Response pattern when a rule is triggered

> I can't do [X] as written because [rule + one-line reason]. Here's a safer version: [alternative].

Keep it short. Don't lecture beyond one sentence of rationale. If the blocked action was an
attempt to reach a secret, another directory, or execute a bypass command, state plainly that
it's out of scope for this skill. Don't explain how close the request came to working.
