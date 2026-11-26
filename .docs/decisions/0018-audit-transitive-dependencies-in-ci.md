# Audit Transitive Dependencies in CI

## Context and Problem Statement

GitHub's dependency graph does not read `bun.lock`, so Dependabot alerts cover direct dependencies only, as record 0017 explains.
`bun audit` is the only tool here that sees transitive advisories, and nothing runs it automatically.
An advisory is published regardless of what a pull request changes, so a check on every pull request can fail work that has nothing to do with dependencies.
A scheduled run has the opposite problem: GitHub notifies only the user who last edited the cron line, so a failure can go unseen.

How should new transitive advisories become visible without blocking unrelated pull requests?

## Considered Options

- Add `bun audit` as a step in `validate.yml`
- Add an `audit.yml` workflow that runs on dependency-changing pull requests and weekly, and opens an issue when the weekly run fails
- Submit `bun.lock` to GitHub through the dependency submission API so that Dependabot raises the alerts

## Decision Outcome

Chosen option: "Add an `audit.yml` workflow that runs on dependency-changing pull requests and weekly, and opens an issue when the weekly run fails", because it covers both new advisories and new dependencies, and leaves unrelated pull requests alone.

A step in `validate.yml` was rejected because every pull request would go red on a new advisory, and a weekly trigger there would also rerun lint and tests.
A separate workflow also gives the failure its own check name, and limits `issues: write` to the job that needs it.
The dependency submission API was rejected because its documentation lists no Bun action, so it would need a `bun.lock` converter to write and maintain, and it does not state that submitted dependencies feed alerts.

The pull request trigger is filtered to `bun.lock`, `package.json` files and the workflow itself.
The threshold is `--audit-level=high`, because the three advisories accepted in record 0017 are moderate or low.
A dependency-changing pull request can still fail on an advisory it did not introduce, so the error annotation says so.
`bun audit` exits 1 for both advisories and a failed registry request, so the step reads its report and states which of the two happened.
The job skips `bun install`, because `bun audit` only needs `bun.lock`.

When the check fails, run `bun audit fix` first, then follow the approach in record 0017 for what is left.
To accept a high advisory, add `--ignore=<GHSA id>` to the audit command and record the reason in `.docs/decisions/`.

### Consequences

- Good, because new high and critical advisories in transitive packages now fail visibly, within a week at most.
- Good, because a failed weekly run leaves an open issue, and later failures comment on it instead of opening duplicates.
- Good, because a registry outage is not reported as an advisory.
- Bad, because a new advisory stays invisible on pull requests until the weekly run or a dependency change picks it up.
- Bad, because moderate and low advisories are not reported, so they still need a manual `bun audit`.
- Bad, because the failed-run issue stays open until someone closes it, since nothing closes it when the audit recovers.
- Bad, because telling the two failures apart depends on the wording of `bun audit`, and a change there would report advisories as "could not run".
- Bad, because making this a required check means removing the path filter first, since GitHub leaves a required check pending when path filtering skips its workflow.
