# Lock the production migration environment to master

## Context and Problem Statement

ADR 0040 migrates the production database from the `Migrate Production Database` workflow when a migration is merged into `master`.
The workflow reads `DATABASE_URL` from the `production` GitHub environment, but that environment has no deployment branch policy.
Workflow files are code: a pull request can edit `validate.yml`, or add a workflow, and the changed files run on that pull request.
Such a job can declare `environment: production`, receive the production `DATABASE_URL` and run `db:migrate`, or anything else, against production before anyone reviews the change.
The `production` and `preview` names are also the environments Vercel creates for its deployment statuses, so the database secret would sit next to records written by another tool.
How do we make sure only `master` can reach the production database, whatever a pull request changes in `.github/workflows/`?

## Considered Options

- A dedicated `production-database` environment whose deployment branch policy allows `master` only
- Keep the `production` environment and add the `master`-only policy to it
- Require a reviewer's approval on the `production` environment
- Guard the job with `if: github.ref == 'refs/heads/master'` only
- A CI check that fails when a pull request workflow references the production environment

## Decision Outcome

Chosen option: "A dedicated `production-database` environment whose deployment branch policy allows `master` only", because GitHub enforces the policy on its side, so no change to a workflow file can lift it.

- The policy is a custom branch rule with the single branch `master`, and no tag rule.
  GitHub matches it against `GITHUB_REF`: pull request runs use `refs/pull/<number>/merge` and pushes to other branches use their own branch name, so their jobs cannot enter the environment and never receive its secrets.
- `DATABASE_URL` is stored only as a secret of `production-database`, never as a repository or organization secret, which every workflow can read.
- Pull request workflows never reference `production-database`.
  A pull request job that needs a database uses a separate environment (for example `preview-database`) holding the URL of a Neon preview branch.
- `Migrate Production Database` declares `environment: production-database` and keeps an `if: github.ref == 'refs/heads/master'` guard so a manual run from another branch is skipped with a clear reason.
- The `production` and `preview` environments stay Vercel's deployment records and hold no secrets.
- `.docs/how-to/deploy-to-vercel.md` gives the `gh` commands that create the environment, its policy and its secret in each project created from this boilerplate.

Reusing `production` was rejected because environment names are shared with Vercel's deployment statuses, and a separate name makes the environment's single purpose obvious in the workflow and in the settings.
A required reviewer alone was rejected because anyone allowed to approve could approve a run from an unreviewed branch; it can be added on top of the branch policy later.
An `if:` guard alone, or a CI check, was rejected because the pull request that edits the workflows can remove them too; the guard stays only as a clearer error.

### Consequences

- Good, because a pull request cannot reach the production database, whatever it changes in `.github/workflows/`.
- Good, because a run from the wrong branch fails before it starts, with GitHub's branch policy error.
- Bad, because the guarantee holds only while `master` itself only accepts reviewed pull requests: a direct push to `master` runs with `GITHUB_REF=refs/heads/master`.
  Protect `master` with a ruleset or branch protection that requires a pull request.
- Bad, because the environment, its policy and its secret must be created by hand, or with the documented `gh` commands, in every project created from this boilerplate; until they are, the workflow fails.
