---
name: conventional-commit-pr
description: Draft a Conventional Commit message or PR title from the staged diff, following the repo's enforced types and scope conventions.
when_to_use: Writing a commit message, drafting a PR title, or squash-merging a branch onto master. Triggered when the user asks for a commit message, opens a PR, or runs into commitlint failures.
user-invocable: true
---

# Conventional Commit / PR

Commit messages **and** PR titles in this repo are checked by
`@commitlint/config-conventional` — squash-merges produce a Conventional
Commit on `master`, so the PR title is what ships.

The full rule lives at
[`.agents/rules/conventional-commits.md`](../../rules/conventional-commits.md).

## Procedure

1. Look at what's actually changing:
   ```bash
   git diff --stat <base>...HEAD
   git diff <base>...HEAD
   ```
2. Pick the **type** that matches the dominant change:
   - `feat` — new user-visible capability
   - `fix` — bug fix
   - `refactor` — restructure without behaviour change
   - `perf` — measurable performance improvement
   - `docs` — docs only
   - `test` — tests only
   - `chore`, `build`, `ci`, `style`, `revert` — see the rule file
3. Pick a **scope** (optional) by feature or package — examples in this
   repo: `auth`, `payment`, `email`, `deps`, `monitoring`. Prefer existing
   scopes over inventing new ones.
4. Write the subject:
   - imperative mood ("add", not "added" / "adds")
   - lowercase, no trailing period
   - under 100 characters
5. If the change is breaking, append `!` after the type/scope **and**
   add a `BREAKING CHANGE:` footer explaining the migration.
6. Body (optional, blank line before): wrap at ~100 cols, explain the
   **why**, not the what — the diff already shows the what.

## Examples drawn from this repo

```
feat(auth): add OAuth2 login with Google
fix(payment): correct Stripe webhook signature validation
chore(deps): bump next from 15.2.5 to 15.3.0
refactor(email)!: replace Mailgun with Resend
```

## Red flags

- Generic subjects: `update stuff`, `WIP`, `Fix bug.`
- Past tense: `added`, `fixed`.
- Multiple unrelated types squashed into one commit — split the PR or
  pick the dominant change and mention the rest in the body.
- A type that doesn't match the dominant change (e.g. `chore:` for a
  user-visible feature).
