# Check the Auth Schema with the Better Auth CLI

## Context and Problem Statement

The Better Auth tables (`users`, `sessions`, `accounts`, `verifications`) are written by hand in `infrastructure/adapters/src/database/drizzle/schema/`.
They follow this repository's conventions: plural table names, `snake_case` columns, the `"default"` Postgres schema and an extra `role` field declared in `user.additionalFields`.
They reach Better Auth through the `schema` mapping passed to `drizzleAdapter`.
Nothing checks that these tables still hold what Better Auth writes, so adding a plugin or a field without the matching column only fails at runtime, on the first sign-in that needs it.
How should the repository catch that drift before it ships?

## Considered Options

- Keep relying on review and manual testing
- Generate the auth schema with `auth generate` and commit its output
- Run `auth check schema` from the official Better Auth CLI (`auth` on npm) in the pre-push hook and in CI
- Write a custom test that compares Better Auth's expected fields with the Drizzle tables

## Decision Outcome

Chosen option: "Run `auth check schema`", because it is maintained with Better Auth, reads the configured Drizzle schema object without a database connection, and reports the exact missing columns (for example `user.role`, `session.token`).
It was checked against the current schema (passes) and against a copy with `role` and `token` removed (fails with exit code 1 and lists both).

The CLI is a devDependency of `@ship-it/adapters`, pinned exactly to the `better-auth` version so both read the same schema rules.
`@better-auth/cli` was not used: it is deprecated on npm and stopped at 1.4; the CLI now ships as `auth`.
The script sets a placeholder `DATABASE_URL` when none is set, because loading `auth.ts` imports the Drizzle client, which refuses to load without one; no connection is opened.

`auth generate` was rejected as a source of truth: its output does not follow the repository's table names, column names or Postgres schema, so it would replace the hand-written tables instead of checking them.
A custom test was rejected because it would reimplement Better Auth's schema rules and drift from them on upgrade.

### Consequences

- Good, because a missing auth column now fails `bun run check-auth-schema`, the pre-push hook and CI, instead of a production sign-in.
- Good, because the check needs no database or secret, so it runs in CI as is.
- Bad, because `auth` must be bumped together with `better-auth`.
- Bad, because the check only compares the schema object with the config; it does not confirm that migrations were applied, which stays with drizzle-kit.
- Bad, because the CLI's own failure message suggests `npx auth generate`, which this repository does not use; the `drizzle-schema-change` skill says to add the columns by hand.
