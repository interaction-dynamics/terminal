# Fix transitive advisories from `bun audit`

## Context and Problem Statement

After the upgrade to `next` 16.4.5, `bun audit` reported 36 advisories in 10 transitive packages, while Dependabot showed none of them.
GitHub's dependency graph does not read `bun.lock`: it lists only the `package.json` files, and its SBOM has 124 entries against 1116 in the lockfile.
Since the move to Bun on 2026-04-08, Dependabot has raised alerts for direct dependencies only, so `bun audit` is the only tool here that sees transitive advisories.

How should these advisories be fixed, and what should happen when no compatible fix exists?

## Considered Options

- Run `bun audit fix` within declared ranges, then add an override only where an exact pin blocks a same-major fix, and accept what is left when unreachable
- Run `bun audit fix --latest`
- Add a root override for every advisory
- Delete entries from `bun.lock` so that Bun re-resolves the affected subtree

## Decision Outcome

Chosen option: "Run `bun audit fix` within declared ranges, then add an override only where an exact pin blocks a same-major fix, and accept what is left when unreachable", because it fixed 33 of the 36 advisories with a diff of 10 added and 12 removed lines.

`bun audit fix --latest` crosses major versions across the tree.
Overrides for every advisory would force `uuid` and `esbuild` across the ranges their parents declare, for code paths that never call the vulnerable functions.
Bun overrides also apply to every consumer of a package, so a single `esbuild` override would conflict with the `~0.28.0` that `tsx` requires.
Deleting lockfile entries was tried: Bun re-resolved the whole tree and bumped `lockfileVersion`.

`zod` gets one override, to 4.6.7, because `@vercel/oidc` 3.8.2 pins `@vercel/cli-config` 0.2.2, which pins `zod` 4.1.11.
Every other consumer already resolves to 4.6.7, and `@vercel/cli-config` still loads and parses its schema on it.

Three advisories are accepted:

- `deepmerge` 4.3.1 (GHSA-gcqx-w48m-w2h4, low) has no patched release.
  It reaches the server bundle through `html-to-text`, which merges options set in code, not message content.
  The way out is `@react-email/render` 2.2.0, but `@react-email/components` 1.0.12, the latest release, pins 2.0.6.
- `uuid` 8.3.2 (GHSA-w5hq-g745-h8pq, moderate) affects `v3`, `v5` and `v6` when `buf` is provided.
  Its only consumer, `statsig-node-lite`, calls `v4` without `buf`, and its latest release still requires `^8.3.2`.
- `esbuild` 0.18.20 (GHSA-67mh-4wv8-2f99, moderate) affects the development server.
  It is a development-only dependency of `drizzle-kit` 0.31.11, the latest release, through `@esbuild-kit/core-utils`, which only calls `transform` and `transformSync`.

### Consequences

- Good, because all 20 high advisories are gone and the lockfile diff stays small enough to review line by line.
- Good, because no package moves to a new major version.
- Bad, because the `zod` override holds every consumer at 4.6.7, so a future bump of `zod` must update the override too.
  Remove the override once `@vercel/oidc` moves to a `@vercel/cli-config` release with a compatible range.
- Bad, because `bun audit` keeps listing the three accepted advisories, so they must be rechecked when `@react-email/components`, `statsig-node-lite` or `drizzle-kit` release a new version.
- Bad, because nothing runs `bun audit` automatically yet, so new transitive advisories stay invisible until someone runs it by hand.
