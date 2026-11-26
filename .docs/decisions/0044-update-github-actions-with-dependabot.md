# Update GitHub Actions with Dependabot

## Context and Problem Statement

Dependabot updates the Bun packages, but nothing updates the actions the workflows use, such as `actions/checkout@v6`, `oven-sh/setup-bun@v2`, `actions/setup-node@v7` and `actions/upload-artifact@v7`.
An outdated action keeps running until GitHub deprecates its runtime, and then every workflow that uses it fails at once.
How should the workflow actions stay up to date?

## Considered Options

- Bump the actions by hand
- Add a `github-actions` ecosystem to the existing `.github/dependabot.yml`
- Replace Dependabot with Renovate

## Decision Outcome

Chosen option: "Add a `github-actions` ecosystem to the existing `.github/dependabot.yml`", because it reuses the bot that already updates the Bun packages and needs no extra app or secret.
Bumping by hand was rejected because nobody is reminded to do it.
Renovate was rejected because it means installing another GitHub App and migrating the Bun configuration, for little gain on actions alone.

All action updates are grouped into one weekly pull request, since they rarely conflict.
The commit message prefix is set to `ci` with the `deps` scope, so the pull request title passes the Conventional Commits check in `pr-title.yml`.
The Node version pinned by ADR 0041 is still bumped by hand: Dependabot does not read `mise.toml` or the `node-version` input of `actions/setup-node`.

### Consequences

- Good, because action updates, including runtime migrations, arrive as reviewed pull requests that CI validates before merge.
- Good, because grouping keeps it to at most one extra pull request a week.
- Bad, because one broken action in the group blocks the others until it is fixed or removed from the pull request.
- Bad, because the actions stay pinned to major tags rather than commit SHAs, so a compromised tag would still run.
