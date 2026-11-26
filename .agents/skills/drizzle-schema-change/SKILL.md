---
name: drizzle-schema-change
description: Add or change a persisted domain entity safely — entity in core, schema in drizzle, migration generated, types regenerated.
when_to_use: Creating a new domain model that needs persistence, adding/removing fields on an existing one, or changing column types. Triggered by edits under `apps/web/src/entities` or `infrastructure/adapters/src/database/drizzle/schema.ts`.
user-invocable: false
---

# Drizzle Schema Change

Persistence flows from domain entities → drizzle schema → migration. Keep
the two in sync; the entity is the source of truth.

## Steps

1. **Define / update the entity** in `domain/entities/src`. Keep it
   free of ORM concerns — plain types validated with Zod.
2. **Mirror the change in drizzle** in
   `infrastructure/adapters/src/database/drizzle/schema/`. Names use
   `snake_case` columns mapping to the camelCase entity fields.
3. **Check the auth tables** when you touch `users`, `sessions`,
   `accounts` or `verifications`, or add a Better Auth plugin or
   `additionalFields`:
   ```bash
   bun run check-auth-schema
   ```
   It lists the columns Better Auth needs but the schema lacks. Add them
   by hand in the schema files; do not run `auth generate` over them,
   because its output does not follow this repo's table names, column
   names or Postgres schema.
4. **Generate the migration**:
   ```bash
   cd infrastructure/adapters && bun run db:generate
   ```
   Inspect the generated SQL — Drizzle will sometimes propose a destructive
   change when a rename was intended.
5. **Apply locally** with `bun run db:migrate` (same folder) and verify with
   `bun run db:studio` if a visual check helps.
   Point `DATABASE_URL` at a development database or Neon branch, never
   production: the `Migrate Production Database` workflow migrates
   production when the pull request is merged into `master` (ADR 0040).
   Keep the migration compatible with the code still live during the
   deploy (expand now, contract in a later pull request).

## Add vs change vs rename

- **Add column**: prefer nullable + backfill + non-null in a follow-up
  migration when the table is large.
- **Drop column**: ship deprecation in code first, then drop in a later
  migration so rollbacks remain safe.
- **Rename column**: use Drizzle's rename helper instead of accepting
  the default drop+add, which loses data.

## Red flags

- Editing only the schema without updating the entity (drift).
- Hand-writing SQL migrations instead of generating them.
- A migration that adds a `NOT NULL` column with no default on a
  populated table.
- Running `db:migrate` against the production database by hand.

## Why

The entity is what features depend on; drift between it and the schema
is silent and only surfaces at runtime. Generated migrations also give
reviewers a clean SQL diff to scrutinise.
