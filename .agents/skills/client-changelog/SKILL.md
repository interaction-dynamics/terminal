---
name: client-changelog
description: Write a client-facing changelog from the feat and fix commits merged since a given date, rewritten in plain language and grouped by type.
when_to_use: The user asks for a changelog, release notes, a "what's new" or an update email for a client covering the work done since a date (or since the last update, a delivery or a meeting).
user-invocable: true
argument-hint: <since YYYY-MM-DD> [until YYYY-MM-DD] [language]
---

# Client Changelog

Turns the commit history of the default branch into release notes a client
can read: only new features and bug fixes, in plain language, grouped by type.

Commit titles follow Conventional Commits
([`.agents/rules/conventional-commits.md`](../../rules/conventional-commits.md)),
so the type of each commit on the default branch says whether it is a feature,
a fix or an internal change.

## Inputs

- **Since** (required): the first day to include, as `YYYY-MM-DD`.
  Convert a relative date ("since last Monday", "since the 1st") to an absolute one.
  If the user gives none, ask for it.
- **Until** (optional): the last day to include. Defaults to today.
- **Language** (optional): the language the client reads.
  Defaults to the language the user writes in.

## Procedure

1. Collect the commits from the repository root:

   ```bash
   .agents/skills/client-changelog/scripts/collect-commits.sh <since> [until]
   ```

   The script fetches `origin`, reads the default branch (`origin/HEAD`, else
   `origin/master` or `origin/main`), skips merge commits and keeps only
   `feat` and `fix` commits (`chore`, `build`, `ci`, `docs`, `test`,
   `refactor`, `perf`, `style` and `revert` are dropped).
   It prints `date<TAB>hash<TAB>subject` per commit, oldest first, and the
   count of skipped commits per type on stderr.

2. Drop the commits a client never sees, even when typed `feat` or `fix`:
   dependency upgrades (`deps`), lint, CI, tests, developer tooling, agent
   skills and rules, internal refactors labelled as fixes, and infrastructure
   changes with no visible effect.
   When unsure whether a change is visible, read the pull request
   (`gh pr view <number>`) or the diff (`git show --stat <hash>`) and decide.

3. Rewrite each kept commit for the client:
   - Describe what the user can now do, or what now works, not what the code does.
     `feat(admin): group users by teacher on the users page`
     → "Users are now grouped by teacher on the users page."
   - Use plain words: no scopes, commit types, pull request numbers, hashes,
     file names, library names or jargon (API, endpoint, adapter, migration,
     refactor, schema…).
     Keep product names and terms the client uses.
   - Write fixes as the behaviour that now works ("Scan cards now keep the same
     height."), not as the bug.
   - One bullet per visible change: merge commits that describe the same change,
     and fold a fix into the feature it completes when both ship in the period.
   - Do not invent anything the commit and its pull request do not say.

4. Group by type, in this order, and omit an empty group:
   - **New features** (`feat`)
   - **Bug fixes** (`fix`)

   Within a group, put the changes the client cares most about first.
   Translate the headings with the rest of the changelog.

5. Reply with the changelog in a Markdown block ready to paste in an email or
   a document:

   ```markdown
   ## What's new from 3 to 23 November 2026

   ### New features

   - Sessions can now have an optional one-line description.
   - New sessions allow 1 scan per student by default.

   ### Bug fixes

   - The app now works on iPadOS 15 and older Chromebooks.
   ```

   Below the block, list for the user (not the client) the `feat`/`fix`
   commits you dropped in step 2 and why, so they can put one back.
   If nothing is left after filtering, say so instead of writing an empty
   changelog.

## Red flags

- A `chore`, `build`, `ci`, `docs`, `test` or `refactor` commit in the changelog.
- A bullet that still reads like a commit title (scope, imperative verb, jargon,
  `#123`).
- Commits from a local branch instead of the default branch on `origin`.
- A `--since` date that silently excludes the first day (the script pins it to
  midnight; keep it that way if you run `git log` by hand).
