# Conventional Commits

Apply this rule when writing commit messages and pull request titles.

## Rule

Commit messages and pull request titles MUST follow the
[Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) specification.

## Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

- Use the imperative, present tense ("add", not "added" or "adds").
- Keep the subject line under 100 characters.
- Lowercase the description; do not end it with a period.
- Separate the subject from the body with a blank line.
- Wrap body lines at ~100 characters and explain the _why_, not the _what_.

## Allowed types

These types are enforced by `@commitlint/config-conventional` (see
`.config/commitlint.config.ts`):

- `build` — changes to the build system or external dependencies
- `chore` — maintenance tasks that do not modify source or tests
- `ci` — changes to CI configuration files and scripts
- `docs` — documentation only changes
- `feat` — a new feature (correlates with `MINOR` in SemVer)
- `fix` — a bug fix (correlates with `PATCH` in SemVer)
- `perf` — a code change that improves performance
- `refactor` — a code change that neither fixes a bug nor adds a feature
- `revert` — reverts a previous commit
- `style` — formatting, white-space, missing semi-colons, etc.
- `test` — adding or correcting tests

## Scope

A scope MAY be added after the type to provide additional context, wrapped in
parentheses:

```
feat(parser): add ability to parse arrays
```

Prefer scoping by feature or package (for example `feat(auth):`,
`fix(payment):`, `chore(deps):`).

## Breaking changes

A commit that introduces a breaking API change MUST either:

1. Append `!` after the type/scope:
   ```
   feat(api)!: drop support for Node 18
   ```
2. Or include a `BREAKING CHANGE:` footer:

   ```
   feat(api): drop support for Node 18

   BREAKING CHANGE: minimum supported Node version is now 20.
   ```

Breaking changes correlate with `MAJOR` in Semantic Versioning, regardless of
the type used.

## Footers

Footers follow the
[git trailer format](https://git-scm.com/docs/git-interpret-trailers). Common
footers include:

- `BREAKING CHANGE: <description>` — describes a breaking API change.
- `Refs: <issue>` — links a related issue.
- `Co-authored-by: <name> <email>` — credits a co-author.

## Examples

Good:

```
feat(auth): add OAuth2 login with Google
fix(payment): correct Stripe webhook signature validation
chore(deps): bump next from 15.2.5 to 15.3.0
docs(contributing): clarify commit message rules
refactor(email)!: replace Mailgun with Resend
```

Bad:

```
update stuff
WIP
Fix bug.
Added new feature for the marketing page
```

## Why

- The commit type drives automated versioning via `standard-version`.
- Reviewers can scan history quickly when commits follow a predictable shape.
- The same convention is enforced for PR titles so squash-merges produce a
  valid Conventional Commit on `master`.
