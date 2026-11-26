# Pin Local Tool Versions with mise

## Context and Problem Statement

The repository pins Bun through `packageManager` in `package.json`, but nothing installs that version for a contributor.
Node has no pin at all, even though `@types/node` already targets Node 26, so each machine runs whatever its version manager last selected.
A mismatch between local tools and the versions the code expects shows up as confusing install, type, or runtime errors.
How should the repository declare the Bun and Node versions used for local development?

## Considered Options

- Keep the current setup and rely on each contributor's own tools
- Add `.nvmrc` for Node and keep installing Bun separately
- Use Volta
- Use asdf with a `.tool-versions` file
- Use mise with a `mise.toml` file

## Decision Outcome

Chosen option: "Use mise with a `mise.toml` file", because one committed file installs and activates both Bun and Node, per directory, across macOS and Linux.
`.nvmrc` was rejected because it covers Node only.
Volta was rejected because its own README declares the project unmaintained.
asdf was rejected because mise covers the same need with a faster runtime and no per-tool plugin setup.
Bun is pinned exactly to match `packageManager`.
Node is pinned to the 26 LTS line, so patch releases arrive without a repository change.
mise stays optional, and CI continues to use `oven-sh/setup-bun`, which reads `packageManager`.

### Consequences

- Good, because `mise install` gives a contributor the expected Bun and Node versions in one step.
- Good, because mise switches versions by directory, so other projects on the same machine keep their own versions.
- Good, because contributors who do not use mise are unaffected.
- Bad, because the Bun version now lives in both `package.json` and `mise.toml`, and the two must be updated together.
- Bad, because CI does not read `mise.toml`, so it does not enforce the Node pin.
- Bad, because each new checkout or worktree needs `mise trust` before mise applies the file.
