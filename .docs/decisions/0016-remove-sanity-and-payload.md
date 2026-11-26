# Remove Sanity and Payload from the boilerplate

## Context and Problem Statement

Every new project starts from this boilerplate and inherits all of its vendor code and dependencies, whether it uses them or not.
Sanity and Payload account for most of that cost: removing them shrinks a fresh install from about 1426 MB and 129k files to about 871 MB and 64k files.

A project that deletes an adapter also risks rebase conflicts on later `git pull boilerplate master --rebase` runs whenever that adapter changes upstream.

## Considered Options

- Remove Sanity and Payload entirely
- Move them into optional packages that projects install on demand
- Keep them in the boilerplate

## Decision Outcome

Chosen option: "Remove Sanity and Payload entirely", because building a custom CMS with json-render is now easy enough that neither tool justifies its weight in every new project.
It also removes that dependency weight and vendor code with no packages to publish or maintain.

Optional packages were built and tested first.
They worked, but they needed a publishing pipeline, a dedicated repository, and several manual install steps per project, for two integrations that aren't needed by default.

The `content-management` capability stays, with a `ContentClient` port and a blank adapter, so `/blog` keeps working and a CMS can be added behind the port later.
Markdown support is unchanged.

This supersedes "Manage content with Sanity.io" (0005) and "Use better-auth for Payload CMS admin authentication" (0025).

### Consequences

- Good, because new projects install about 39% less by size and 50% fewer files.
- Good, because a project can't hit rebase conflicts on CMS code that it never had.
- Good, because there are no extra packages to version or publish.
- Bad, because `/blog` shows no posts until a project adds a CMS adapter.
- Bad, because a project that wants Sanity or Payload must write its own adapter, or recover the old one from git history at commit `919216a6`.
