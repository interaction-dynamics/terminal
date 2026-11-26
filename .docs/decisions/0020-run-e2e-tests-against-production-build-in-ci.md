# Run End-to-end Tests Against a Production Build in CI

## Context and Problem Statement

ADR 0019 left the end-to-end job in `Validate Code` commented out, because it had never run on Bun.
Its design also wasted work: it built the application and then ran the tests, but Playwright started the dev server, so the build was thrown away.
Playwright itself could not start, because its config used `__dirname` in an ES module.
The suite also skipped its accessibility test, which failed on real violations.
How should CI run the end-to-end tests, against which server and which browsers?

## Considered Options

- Separate job on `ubuntu-latest`, production server, all configured browsers
- Separate job on `ubuntu-latest`, dev server, all configured browsers
- Separate job on `ubuntu-latest`, production server, Chromium only
- Add the tests to the existing `Validate Code` job on `ubuntu-slim`
- Reuse the `Validate Code` build through an artifact instead of building again

## Decision Outcome

Chosen option: "Separate job on `ubuntu-latest`, production server, all configured browsers", because it tests what actually ships and keeps the same browser matrix locally and in CI.
Playwright starts `next start` when `CI` is set and `next dev` otherwise, so local runs need no build.
A dev server was rejected because it compiles routes on first request, which adds time and flakiness, and it would test different output from production.
Chromium only was rejected because the suite is three small files, so the extra browsers cost little and catch engine differences.
The existing job was rejected because four browser projects are a poor fit for the single CPU of `ubuntu-slim`, and a separate status shows clearly when only the browser tests fail.
Sharing a build artifact was rejected for now because it makes this job depend on `Validate Code` and adds upload and download steps to save one build.
Browsers are not cached, because `playwright install --with-deps` must still install the operating system packages on every run.

The job needs no environment variables or secrets: the app builds and serves the tested pages with nothing set, because adapters fall back to their blank implementations.
It sets only `NEXT_TELEMETRY_DISABLED`, and it drops the workflow's `id-token: write` permission, which it does not use.
Traces from failed runs are uploaded as an artifact, kept for seven days.

The accessibility test is enabled and covers the landing page in light and dark mode.
Its violations were fixed rather than excluded, because they were small and each one was a real defect.

### Consequences

- Good, because a broken page, a missing landmark or a contrast regression on the landing page now blocks a pull request.
- Good, because tests run against the same output as production.
- Good, because the job works in a new project with no secrets configured.
- Bad, because the application is built twice per run, once in each job.
- Bad, because the job adds about two minutes per run, measured on its first run on GitHub.
- Bad, because running `CI=1 bun run test:e2e` locally fails unless `bun run build` ran first.
- Bad, because tests that need a database, authentication or email are not possible without adding test services or secrets to this job.
- Bad, because the accessibility test only covers the landing page.
