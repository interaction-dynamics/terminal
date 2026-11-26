# Type Check and Build in CI

## Context and Problem Statement

The `Validate Code` workflow ran lint, format and unit tests, but nothing compiled the code.
Type errors and bundling failures, such as a missing dependency or a broken adapter import, first appeared when a Vercel deployment failed.
The repository also had no task that type checked `infrastructure/adapters` and `domain/entities`, because `apps/web` only reaches the files it imports.
How should CI catch compile and build failures before a pull request merges?

## Considered Options

- Add type check and build steps to the existing job
- Add a separate job on a larger runner
- Keep relying on Vercel deployment checks

## Decision Outcome

Chosen option: "Add type check and build steps to the existing job", because the single `Validate Code` status stays the one result to read, and any branch rule that requires it covers the new steps automatically.
A separate job was rejected for now because a local build peaks near 2 GB of memory and uses about 45 seconds of CPU time, which is small enough to try on `ubuntu-slim` first.
Vercel checks were rejected because they only run for projects linked to Vercel, and new projects start from this repository before that link exists.

Each workspace runs `tsc --noEmit` through a `check-types` Turborepo task.
It uses a transit node, as the Turborepo docs recommend, so the tasks run in parallel and a change in a dependency still invalidates the cache of its dependents.
The job installs Node 26 with `actions/setup-node`, because `next build` runs on Node and the `ubuntu-slim` image ships Node 24 while `mise.toml` pins Node 26.

End-to-end tests stay disabled, because they are outside this decision and have never run on Bun in CI.

### Consequences

- Good, because type errors and build failures now block a pull request.
- Good, because the build needs no secrets: adapters fall back to their blank implementations when environment variables are unset.
- Good, because the Node version in CI now follows the pin, which resolves the gap noted in ADR 0015.
- Bad, because the Node major version now lives in both `mise.toml` and the workflow, and the two must be updated together.
- Bad, because `next build` also type checks `apps/web`, so that workspace is checked twice per run.
- Bad, because the job is slower, and the build has not yet been measured on a real `ubuntu-slim` run, so it may need a larger runner.
- Bad, because a green build says nothing about known vulnerabilities: the workflow does not run `bun audit`, and Next's upgrade notice does not fire in CI.
