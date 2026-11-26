# PR Watching

Apply this rule whenever you create a pull request in this repository,
and at the start of every session when the current branch already has an
open PR.

## Rule

**When creating a PR** — immediately subscribe to its activity with
`subscribe_pr_activity` — do not wait to be asked — return the PR URL
to the user, then end the turn.

**At session start** — check whether the current branch has an open PR
(e.g. with `mcp__github__list_pull_requests`). If one exists, subscribe
to it with `subscribe_pr_activity` before doing anything else.

**When the task is complete** — push all local commits and confirm the
PR is up to date before ending the turn.

While subscribed, investigate every PR event you receive and choose one
of the following:

- **Confident, in-scope fix** — push the fix and refresh your status
  checklist. Reply only when the fix resolves the task or raises a
  question; otherwise let the PR diff be the record.
- **Ambiguous or architecturally significant** — use `AskUserQuestion`
  before acting, with enough context to answer without scrolling back.
- **Duplicate or no action needed** — skip silently.

### CI failures

When a CI check fails, diagnose the root cause from the job logs and
push a fix. Keep re-diagnosing and re-kicking on each new failure until
CI is fully green or you hit a real, out-of-scope blocker. On success,
reply with the green status.

### Review comments

When a reviewer leaves a comment or requests changes, address every
thread. For each thread:

1. Apply the fix if it is clear and in scope.
2. Reply on the thread to explain the change (or why you did not make it).
3. Resolve the thread once the fix is pushed.

Stop watching the moment the user asks: call `unsubscribe_pr_activity`
and push no further changes to that PR.

## Why

PRs are the unit of review here, and feedback (CI, reviewers) arrives
after the PR is opened. Subscribing automatically — including on session
resume — means that feedback is acted on promptly without the author
having to babysit the session or remember to ask.
