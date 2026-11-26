# Domain Entities

Apply this rule when introducing a new domain model or changing the
shape of a persisted one.

## Rule

The entity is the source of truth. Persistence mirrors it; it does not
drive the other way round.

When a new domain model is created:

1. Add the entity to `domain/entities/src` (`@ship-it/entities`). Keep it free of ORM
   concerns — plain types validated with Zod.
2. If the model needs persistence, add the database representation to
   `infrastructure/adapters/src/database/drizzle/schema.ts`.
3. Generate the migration with `cd infrastructure/adapters && bun run db:generate`,
   inspect the SQL diff, and test it on a development database or Neon
   branch before committing. Never migrate production by hand: the
   `Migrate Production Database` workflow does it when the pull request
   is merged into `master` (ADR 0040).

When changing an existing entity:

- Update the entity first, then mirror the change in the drizzle schema,
  then regenerate the migration.
- For renames, use Drizzle's rename helper — the default drop+add loses
  data.
- For large tables, ship a nullable column + backfill + non-null follow-up
  rather than a single non-null add.

## Red flags

- A field on the drizzle schema that has no equivalent on the entity
  (silent drift).
- An entity that imports from drizzle (the dependency must flow the
  other way).
- Hand-written SQL migrations.
- A migration that breaks the code still live during the deploy (it
  runs while the previous release is serving traffic).

## Why

Features depend on the entity, not on the table. Drift between the two
is silent at compile time and only surfaces at runtime. Generated
migrations also give reviewers a clean SQL diff to scrutinise.
