# Pin Node to an Exact Version

## Context and Problem Statement

ADR 0015 pinned Node to the 26 LTS line in `mise.toml`, so patch releases arrived without a repository change, and ADR 0019 installed the same `26` line in CI.
A floating major means two machines, or two CI runs a week apart, can build with different Node releases, and nothing in the history says which one a build used.
Bun is already pinned to an exact version, so Node is the only tool whose version moves on its own.
How precisely should the repository pin Node?

## Considered Options

- Keep the floating `26` major
- Pin an exact version, such as `26.13.1`, in `mise.toml` and CI

## Decision Outcome

Chosen option: "Pin an exact version, such as `26.13.1`, in `mise.toml` and CI", because every machine and every CI run then uses the same Node release, and a Node upgrade becomes a reviewed commit that CI validates before merge.
The floating major was rejected because a Node patch release could change a build or test result with no matching change in the repository.
This supersedes the Node part of ADR 0015; its choice of mise is unchanged.

To upgrade Node, change the version in `mise.toml` and in both `actions/setup-node` steps of `.github/workflows/validate.yml` in the same commit.

### Consequences

- Good, because local development and CI run the same Node release.
- Good, because a Node upgrade shows up in the history and runs through CI like any other change.
- Bad, because Node security patches no longer arrive automatically, so someone must bump the version.
- Bad, because the version lives in three places that must be updated together, and Dependabot does not update any of them.
