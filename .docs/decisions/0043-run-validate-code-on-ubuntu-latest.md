# Run Validate Code on ubuntu-latest

Superseded by [ADR 0048](0048-run-ci-on-ubuntu-slim-for-pull-requests-only.md).

## Context and Problem Statement

ADR 0019 added the type check and `next build` to the `Validate Code` job on `ubuntu-slim`, and noted that the build had not been measured there and might need a larger runner.
A normal run takes about 3 minutes, but two runs were cancelled with "The operation was canceled" and nothing else in the log.
Run 44308830736 (PR #100) passed every step up to the build in 3.5 minutes, then printed nothing after "Running build in 4 packages" from 13:00:56 until the cancellation at 13:13:51; the re-run of the same commit passed in 3.5 minutes.
Run 44192186415 (PR #98) never reached the build: every step was 5 to 25 times slower than usual (install 5 minutes instead of 20 seconds, type check 4.5 minutes instead of 10 seconds), and it was cancelled during the unit tests.
The `End-to-end Tests` job runs the same `bun run build` on `ubuntu-latest` and has not stalled.
Memory pressure during `next build` was the leading hypothesis, because ADR 0030 already works around the memory of `ubuntu-slim` for knip.
What causes the cancellations, and how should the workflow avoid them?

### Findings

- Both jobs were cancelled about 15 minutes after they started, with no `timeout-minutes` set (the default is 360) and nobody cancelling them.
  That matches the 15-minute job limit of `ubuntu-slim`, so the platform ended both jobs, not a hang detector.
- The silence is Turborepo, not Next.js: in CI `turbo` defaults to the `grouped` log order and prints a task's output only once the task ends.
  A slow build and a hung build look the same in the log.
- A local clean build in a cgroup limited to one CPU and 5 GiB, the size of `ubuntu-slim`, finished in 1 minute 32 seconds with a peak of 2.7 GiB, page cache included, and no OOM kill.
- With the limit lowered to 2 GiB the kernel killed the build within a minute (exit 137) and `turbo` reported the failure, so running out of memory fails fast instead of stalling silently.
- With one CPU throttled to 20%, standing in for a slow runner, the same build took 6 minutes 24 seconds, peaked at 2.3 GiB, and printed nothing after "Running build in 4 packages" for 6 minutes 21 seconds, then its whole log at once: the pattern of the PR #100 run.
- The PR #98 run was slow before any build started, which no Next.js setting can explain.

The cause is a slow `ubuntu-slim` runner pushing the job past its 15-minute limit, not memory use in `next build`.

## Considered Options

- Run the `Validate Code` job on `ubuntu-latest`
- Run only the build step on `ubuntu-latest`, in a separate job
- Cap Next.js build workers or the Node heap (`experimental.cpus`, `NODE_OPTIONS=--max-old-space-size`)
- Keep `ubuntu-slim` and only add `timeout-minutes`

## Decision Outcome

Chosen option: "Run the `Validate Code` job on `ubuntu-latest`", because it removes both the single vCPU and the 15-minute limit behind the two cancellations, including the PR #98 run that was cancelled before the build.
Running only the build on `ubuntu-latest` was rejected because the PR #98 run hit the limit during the unit tests, and the `End-to-end Tests` job already builds on `ubuntu-latest`.
Capping workers or the heap was rejected because the build peaks well under the 5 GiB of `ubuntu-slim` and fails fast when memory runs out, so it treats a cause the logs and the reproduction rule out.
A timeout alone was rejected because `ubuntu-slim` already ends the job at 15 minutes; a timeout changes the message, not the outcome.

Two changes ship with it, because they make the next slow run diagnosable instead of silent:

- The workflow sets `TURBO_LOG_ORDER=stream`, so the log shows each task's progress as it happens.
- `Validate Code` gets `timeout-minutes: 10` and `End-to-end Tests` gets `timeout-minutes: 15`, about three to five times a normal run, so a stalled job fails with a timeout message well before the 360-minute default.

The knip step keeps `KNIP_DISABLE_RAW_TRANSFER` from ADR 0030 until knip has been tried with raw transfer on `ubuntu-latest`.
The `Audit`, `PR Title` and `Migrate Production Database` workflows stay on `ubuntu-slim`: they run for well under a minute and do not build.
This supersedes the runner choice in ADR 0019; its steps are unchanged.

### Consequences

- Good, because the job no longer depends on a single vCPU or on a 15-minute limit that leaves little margin for a slow runner.
- Good, because Turborepo tasks, Vitest workers and Next.js build workers get more than one core, so a normal run gets faster.
- Good, because streamed logs and an explicit timeout show where a slow run was and why it ended.
- Bad, because the repository is private, so `ubuntu-latest` minutes cost more than `ubuntu-slim` minutes and use more of the included minutes.
- Bad, because `next build` still runs twice per pull request, once in each job, as before.
- Bad, because streamed logs interleave the output of tasks that run in parallel, which is harder to read than grouped output.
- Bad, because the 15-minute limit of `ubuntu-slim` comes from the observed cancellations, not from a check against GitHub's runner documentation in this change.
