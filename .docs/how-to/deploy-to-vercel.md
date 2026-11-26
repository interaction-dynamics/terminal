# Deploy to Vercel

This page sets up a new deployment from the command line: a Neon database, a Vercel project with its environment variables and domain, and a Resend sending domain with a scoped API key.
Every step can run from a coding agent in non-interactive mode.
Why these CLIs are the documented path is recorded in [ADR 0038](../decisions/0038-document-gh-vercel-and-resend-clis-for-agents.md).

The commands were checked with Vercel CLI 50.x, Resend CLI 2.x and GitHub CLI 2.x.
CLI flags change between major versions, so check `--help` when a command fails.

## Install and sign in

| CLI      | Install                 | Sign in                               | Used for                                                         |
| -------- | ----------------------- | ------------------------------------- | ---------------------------------------------------------------- |
| `gh`     | `brew install gh`       | `gh auth login`                       | Pull requests, CI runs and logs (`.agents/rules/pr-watching.md`) |
| `vercel` | `bun add -g vercel`     | `vercel login`                        | Link the project, environment variables, domains, deploys        |
| `resend` | `bun add -g resend-cli` | `resend login --web --profile <name>` | Sending domains, DNS records, scoped API keys                    |

The Resend CLI is the official one: the npm package is `resend-cli` (repository `resend/resend-cli`) and it installs a `resend` binary.
Do not install the `resend` npm package for this; that is the Node SDK the email adapter already depends on.

`resend login --web` opens a browser OAuth flow, works without a TTY and stores the key in the macOS Keychain (or the platform's secure store).
Use one profile per Resend account and select it with `-p <name>` or `RESEND_PROFILE`, for example set per repository with mise or direnv.
An exported `RESEND_API_KEY` overrides every profile, so unset it in the shell that runs the CLI.

## 1. Create the database

The app uses Neon through the `neon-http` driver (`infrastructure/adapters/src/database/drizzle/db.ts`).
Create a Neon project and copy its pooled `postgres://` connection string.

The tables live in the Postgres schema `"default"` (`schemaName` in `infrastructure/adapters/src/database/drizzle/schema/table.ts`), and the first migration does not create it.
On a fresh database, create it before migrating, from the Neon SQL editor or `psql`:

```sql
CREATE SCHEMA IF NOT EXISTS "default";
```

Then apply the migrations.
`drizzle.config.ts` reads `apps/web/.env.local`, but an exported `DATABASE_URL` wins, so you can target another database without editing the file:

```bash
cd infrastructure/adapters && DATABASE_URL="$DATABASE_URL" bun run db:migrate
```

Use one Neon branch per Vercel environment (for example `main` for Production and a `preview` branch for Preview) so previews never write to production data.

Run `db:migrate` by hand only to set up a database or to test a migration on a development branch.
After the first deployment, production is migrated by the `Migrate Production Database` workflow (`.github/workflows/migrate-production.yml`) whenever a pull request that changes `infrastructure/adapters/src/database/drizzle/` is merged into `master` ([ADR 0040](../decisions/0040-migrate-the-production-database-on-merge.md)).
The production connection string lives only in the `production-database` GitHub environment, which only `master` can enter, so no pull request can reach it, even one that edits the workflows ([ADR 0049](../decisions/0049-lock-the-production-migration-environment-to-master.md)).
Create the environment and restrict it to `master` once:

```bash
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
gh api -X PUT "repos/$REPO/environments/production-database" -F 'deployment_branch_policy[protected_branches]=false' -F 'deployment_branch_policy[custom_branch_policies]=true'
gh api -X POST "repos/$REPO/environments/production-database/deployment-branch-policies" -f name=master -f type=branch
```

Then add the secret to that environment (the command prompts for the value):

```bash
gh secret set DATABASE_URL --env production-database
```

Never store the production `DATABASE_URL` as a repository or organization secret, and never reference `production-database` from a workflow that runs on pull requests.
If a pull request job needs a database, give it its own environment (for example `preview-database`) with the URL of a Neon preview branch.
Protect `master` with a ruleset that requires a pull request: the policy trusts every push to `master`.

Until the secret is set, the workflow fails on every merge that touches a migration.

## 2. Create and link the Vercel project

The Next.js app is in `apps/web`, so the Vercel project's **Root Directory** must be `apps/web`.
Create the project (`vercel project add <name>` or the dashboard), set its Root Directory in the project settings, then link the checkout.
From the CLI, the setting is one REST call:

```bash
echo '{"rootDirectory":"apps/web"}' > body.json
vercel api "/v9/projects/<project-id>?teamId=<team-id>" --method PATCH --input body.json
```

Pick one way to link and stick to it:

- `vercel link --repo` at the repository root links the whole monorepo and writes `.vercel/repo.json`.
- `vercel link --project <name>` writes `.vercel/project.json` for a single project.

With `.vercel/repo.json` present, `vercel link --project` silently does nothing.
Delete `.vercel/` and link again if you need to switch.
`.vercel/` is gitignored.

## 3. Add the environment variables

Every variable is optional and validated at build time; see `apps/web/.env.local.example` and [Add an environment variable](./add-an-environment-variable.md).
A deployment that signs users in and sends email needs:

| Variable             | Production                                    | Preview                  | Development             |
| -------------------- | --------------------------------------------- | ------------------------ | ----------------------- |
| `DATABASE_URL`       | Production Neon branch                        | Preview Neon branch      | Your own branch         |
| `BETTER_AUTH_SECRET` | `openssl rand -base64 32`                     | A different random value | A different value       |
| `BETTER_AUTH_URL`    | The public origin, e.g. `https://example.com` | **Leave unset**          | `http://localhost:3000` |
| `RESEND_API_KEY`     | Scoped key from step 5                        | Scoped key from step 5   | Optional                |
| `RESEND_EMAIL_FROM`  | `App <hello@example.com>`                     | Same                     | Optional                |

Leave `BETTER_AUTH_URL` unset on Preview.
Better Auth then falls back to `https://$VERCEL_URL`, which Vercel sets to each deployment's own URL; a fixed value would send every preview's auth callbacks to one origin.
Production must set it, because `VERCEL_URL` is the deployment URL, not your domain.

Add each variable per environment.
In non-interactive mode (agents are detected automatically), Preview needs an explicit empty Git branch argument, or the command fails with `git_branch_required`:

```bash
vercel env add DATABASE_URL production --value "$PROD_DATABASE_URL" --yes --sensitive
vercel env add DATABASE_URL preview "" --value "$PREVIEW_DATABASE_URL" --yes --sensitive
vercel env add DATABASE_URL development --value "$DEV_DATABASE_URL" --yes
```

`--sensitive` is refused for Development; Development variables must stay readable so `vercel env pull` can write them.
Read secrets into shell variables first rather than typing them on the command line, so they stay out of your shell history.

Pull the Development values into the app's local env file:

```bash
vercel env pull apps/web/.env.local
```

## 4. Add the domain

```bash
vercel domains add example.com <project-name>
```

If that returns `Project not found (404)` (seen with a `--repo` link), call the REST API through the CLI, which reuses its credentials:

```bash
echo '{"name":"example.com"}' > body.json
vercel api "/v10/projects/<project-id>/domains?teamId=<team-id>" --method POST --input body.json
```

The project and team IDs are in `.vercel/repo.json` or `.vercel/project.json`.
Then point the domain's DNS at Vercel as `vercel domains inspect example.com` describes.

## 5. Set up the Resend sending domain

Create the domain and read the DNS records it returns:

```bash
resend domains create --name example.com --region us-east-1 --json
```

Add the returned records at your DNS provider, then trigger verification and check its status:

```bash
resend domains verify <domain-id>
resend domains get <domain-id>
```

Create a send-only API key scoped to that domain for the app.
The token is shown once, and the JSON spans several lines, so parse it rather than grepping:

```bash
RESEND_API_KEY=$(resend api-keys create --name "<project>-production" \
  --permission sending_access --domain-id <domain-id> -q | jq -r .token)
```

Store it straight away with `vercel env add RESEND_API_KEY production --value "$RESEND_API_KEY" --yes --sensitive`, then `unset RESEND_API_KEY` so it does not override your Resend CLI profile.
Use a separate key per environment so one can be revoked without touching the others.

## 6. Deploy and check

Pushing to the production branch deploys through the Git integration; `vercel deploy --prod` deploys from the checkout.
Check the build with `vercel inspect <deployment-url> --logs`, then sign up on the deployed site to confirm the database, auth and email are wired.

`gh pr checks` and `gh run view <run-id> --log-failed` show CI results for the pull request that triggered a preview.
