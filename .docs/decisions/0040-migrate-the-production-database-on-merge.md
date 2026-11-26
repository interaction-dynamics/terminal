# Migrate the production database on merge

## Context and Problem Statement

Schema changes ship as generated Drizzle migrations in `infrastructure/adapters/src/database/drizzle/`, but nothing applies them to production.
Someone has to remember to run `db:migrate` against the production database, either from a session before the code is reviewed (production then runs ahead of `master`, and stays ahead when the pull request is abandoned) or by hand after the merge (production then runs behind the deployed code until someone does it).
When, and by whom, should production be migrated?

## Considered Options

- A GitHub Actions workflow that migrates production when a migration is merged into `master`
- Migrate production by hand, from a session or a laptop, after the merge
- Migrate in the Vercel build (`db:migrate` before `next build`)
- The Vercel and Neon integration, which creates a Neon branch per preview deployment and migrates it in the build

## Decision Outcome

Chosen option: "A GitHub Actions workflow that migrates production when a migration is merged into `master`", because it ties the production schema to what is on `master`, only ever applies reviewed migrations, and does not depend on anyone being around at merge time.

- `.github/workflows/migrate-production.yml` (`Migrate Production Database`) runs `drizzle-kit migrate` on pushes to `master` that change `infrastructure/adapters/src/database/drizzle/`, and can be run by hand from the Actions tab.
- It reads the production URL from the `DATABASE_URL` secret of the `production` GitHub environment, so the environment can require an approval later without changing the workflow.
  ADR 0049 replaced it with the `production-database` environment, which only `master` can enter.
- Runs share one concurrency group and never cancel each other, so two merges in a row migrate one after the other.
- Migrations are tested on a development database or a Neon branch, never on production; agents and developers do not run `db:migrate` against production.

Migrating in the Vercel build was rejected because preview builds would need to be kept away from the production database, and a failed migration would fail the deployment rather than surface as its own check.
The Vercel and Neon integration was not chosen now; it can be revisited if previews need per-pull-request data.

### Consequences

- Good, because production is only migrated from reviewed, merged migrations, and Drizzle's migration journal makes reruns no-ops.
- Good, because a failed migration shows up as a failed workflow run on `master`, with its log.
- Bad, because the Vercel deployment and the migration start together on merge, so every migration must stay compatible with the code that is still live (expand, then contract in a later pull request).
- Bad, because the `DATABASE_URL` secret must be added to the `production` GitHub environment by hand in every project created from this boilerplate; until it is, the workflow fails.
- Bad, because the first migration does not create the `"default"` Postgres schema, so a fresh production database still needs `CREATE SCHEMA IF NOT EXISTS "default";` once before the first run.
