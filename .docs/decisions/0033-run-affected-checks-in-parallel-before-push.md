# Run Affected Checks in Parallel Before Push

## Context and Problem Statement

`.agents/hooks/prepush-check.ts` is a Claude Code `PreToolUse` hook that runs before every `git push` an agent makes.
It ran `format`, `lint`, a full `turbo build` and `commitlint` one after the other, whatever the branch changed.
A branch that only touched docs, rules or tooling still paid for a full Next.js build whenever the build was not cached, and the hook never ran the type check or unit tests that CI runs.
Other tools that agents should hear about before CI, such as `lint:boundaries` and `knip`, are being added as root scripts.
How can the hook give agents faster and broader feedback without letting a broken push through?

## Considered Options

- Run `turbo run build check-types test:ci --affected` and the root checks in parallel
- Keep the sequential full build and add the missing checks after it
- Drop the build from the hook and rely on CI
- Move the checks to a git `pre-push` hook in Lefthook

## Decision Outcome

Chosen option: "Run `turbo run build check-types test:ci --affected` and the root checks in parallel", because it skips packages the branch cannot have broken, runs the remaining work at the same time, and adds type checks and unit tests without adding wall-clock time.

The hook now starts every check at once and waits for all of them:

- `format`, `lint` and `commitlint`, as before.
- `check-adr-numbers`, `lint:boundaries` and `knip`, only when the root `package.json` defines them, so the hook works before and after those scripts land.
- One `turbo run build check-types test:ci --affected --continue=dependencies-successful --output-logs=errors-only` call, which runs the three tasks in parallel inside Turborepo and prints logs only for failing tasks.

`--affected` defaults to comparing against `main`, but this repository's default branch is `master`.
The hook therefore sets `TURBO_SCM_BASE` to the merge-base of `HEAD` and `origin/HEAD`, falling back to `origin/master`, `origin/main`, `master` and `main`.
Using the merge-base SHA of the remote branch keeps a stale local `master`, common in worktrees, from changing the result.
An explicit `TURBO_SCM_BASE` in the environment wins.
When no base resolves, for example in a shallow clone, the hook drops `--affected` and runs the tasks for every package, which is slower but never skips a check.
Turborepo includes uncommitted changes in the comparison, so the hook checks the tree an agent is about to push.
A change to `turbo.json` marks every package as affected, and a change outside any package, such as `.docs` or `.agents`, selects no Turborepo tasks while the root checks still run.

The deny-with-reason output and the `SKIP_PREPUSH_CHECK=1` escape hatch are unchanged.
The reason now lists each check with its duration, and long output keeps its first 20 and last 120 lines, capped at 8,000 characters per check, so the errors at the end survive.
The hook runs its commands from the root of the checkout being pushed: the `cwd` Claude Code passes in the hook input, moved by any `cd <dir>` before the push or by `git -C <dir> push`.
It cannot use its own location or `process.cwd()`, because Claude Code starts it from the project directory, which in a worktree session is the main checkout, not the worktree being pushed.
`.claude/settings.json` sets an explicit 600-second timeout so a cold build cannot hit a shorter default and let the push through.

Measured on an Apple Silicon laptop with the Turborepo cache forced off (`TURBO_FORCE=true`) and `apps/web/.next` deleted before each run, two runs each:

| Change on the branch                 | Before      | After       |
| ------------------------------------ | ----------- | ----------- |
| One line in `.docs/`                 | 11.9–17.5 s | 0.6–1.0 s   |
| One line in `apps/web/src/lib`       | 15.8–22.4 s | 11.0–12.3 s |
| Fresh worktree, first push, no cache | 57.4 s      | not re-run  |

The second row also runs `check-types` and `test:ci` for `@ship-it/web`, which the old hook never ran.
With a warm cache both hooks finish in one to three seconds.
Turborepo 2.11 shares the local cache between linked worktrees, so work done in one agent worktree is a cache hit in the next.

Keeping the sequential build was rejected because the time goes to the build, and adding checks after it would only make the hook slower.
Dropping the build was rejected because `next build` catches errors that `tsc` does not, such as server and client boundary mistakes, and CI feedback arrives minutes later.
A Lefthook `pre-push` hook was rejected for now because it would also run for humans on every push and cannot return a structured reason to the agent; the Claude Code hook can.

### Consequences

- Good, because pushes that only touch docs, rules or tooling skip the build, and code pushes also get type checks and unit tests.
- Good, because failures from several checks arrive in one deny reason, and `--continue=dependencies-successful` reports every independent failing task instead of stopping at the first.
- Good, because new root checks are picked up by adding the script, without editing the hook.
- Bad, because `--affected` works at package level: any file change in `apps/web`, including a README, rebuilds it.
- Bad, because a change at the repository root that affects package tasks without going through `turbo.json` or the lockfile, such as a new root config file a build reads, is not seen as affecting them; CI still runs everything.
- Bad, because running checks in parallel raises peak CPU and memory use while `next build` and `tsc` overlap.
- Bad, because `commitlint` still checks only the last commit, as before.
- Bad, because `@ship-it/web#check-types` reads the route types Next.js generated in `.next/types` during the last local build, so a route removed since then fails the type check until `apps/web/.next` is deleted or rebuilt; CI starts clean and is unaffected.
