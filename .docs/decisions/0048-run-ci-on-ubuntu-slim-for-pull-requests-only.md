# Run CI on ubuntu-slim for pull requests only

## Context and Problem Statement

ADR 0043 moved the `Validate Code` job to `ubuntu-latest` after two runs hit the 15-minute job limit of `ubuntu-slim`, and ADR 0020 put `End-to-end Tests` on `ubuntu-latest` from the start.
The repository is private, so `ubuntu-latest` minutes cost more than `ubuntu-slim` minutes and use more of the included minutes.
The `Validate Code` workflow also ran on every push to `master`, so each merged pull request ran both jobs a second time on content the pull request had already checked.
On `ubuntu-latest` the two jobs take about 1.5 and 2.5 minutes; `Validate Code` took about 3.5 minutes on `ubuntu-slim` before ADR 0043.
How can CI cost less without losing the checks a pull request gets?

## Considered Options

- Run every job on `ubuntu-slim` and run `Validate Code` on pull requests only
- Run every job on `ubuntu-slim` and keep the push run on `master`
- Keep `Validate Code` and `End-to-end Tests` on `ubuntu-latest` and only drop the push run on `master`
- Keep the push run on `master` but skip it when the merged pull request already passed

## Decision Outcome

Chosen option: "Run every job on `ubuntu-slim` and run `Validate Code` on pull requests only", because it uses the cheapest runner for every job and removes the second run of both jobs after each merge.
Keeping the push run was rejected because it repeats the checks of the pull request that was just merged.
Keeping `ubuntu-latest` was rejected to cut the cost of the two jobs that run on every pull request.
Skipping the push run only after a passing pull request was rejected because it needs a lookup of the merged pull request's checks, which is more workflow code for the same result in the common case.

The timeouts from ADR 0043 stay so a stalled job ends with a timeout message: 10 minutes for `Validate Code` and 14 minutes for `End-to-end Tests`, one minute under the `ubuntu-slim` limit.
`TURBO_LOG_ORDER=stream` stays so a slow run shows where it was.
`Validate Code` can still be run on `master` by hand with `workflow_dispatch`.
The `Migrate Production Database` workflow keeps its push trigger on `master`: it migrates on merge and does not repeat a pull request check.
This supersedes ADR 0043 and the runner choice in ADR 0020.

### Consequences

- Good, because every job runs on the cheapest runner.
- Good, because a merge no longer runs `Validate Code` and `End-to-end Tests` a second time.
- Bad, because a slow `ubuntu-slim` runner can again push a job past the 15-minute limit, as in the two runs ADR 0043 describes; re-run the job, and move it back to `ubuntu-latest` if it happens often.
- Bad, because a single vCPU makes both jobs slower, and the four browser projects of the end-to-end tests had not been measured on `ubuntu-slim` before this change.
- Bad, because `master` has no branch protection, so a pull request merged while behind `master` is never checked against the merged result; turn on "Require branches to be up to date before merging" to close that gap.
