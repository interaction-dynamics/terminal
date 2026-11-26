# Use Bun Workspaces

## Context and Problem Statement

ADR 0007 chose pnpm workspaces, but the repository moved to Bun in April 2026 without recording that change.
`package.json` pins Bun through `packageManager`, `bun.lock` is the only lockfile, and CI installs with `oven-sh/setup-bun`.
`pnpm-workspace.yaml`, the Playwright web server command, the `upgrade:dependencies` script and the contributor docs still named pnpm.
A contributor following those references would install with a tool the repository no longer has a lockfile for.
Which package manager should the repository declare, and what should happen to the pnpm references?

## Considered Options

- Use Bun only and remove the pnpm references
- Keep `pnpm-workspace.yaml` so that either tool can install the workspace
- Move back to pnpm

## Decision Outcome

Chosen option: "Use Bun only and remove the pnpm references", because it matches how the repository is already installed, tested and released.
Keeping `pnpm-workspace.yaml` was rejected because no lockfile backs a pnpm install, so its result would be unpinned and untested.
Moving back to pnpm was rejected because it would undo a working migration and gain nothing the repository needs.
This record supersedes the pnpm part of ADR 0007.
The monorepo structure chosen there still stands.
Workspaces are declared in the root `package.json`, and removing `pnpm-workspace.yaml` leaves `bun.lock` and the installed layout unchanged.

### Consequences

- Good, because the repository has one declared package manager and one lockfile.
- Good, because contributors and agents no longer get conflicting install instructions.
- Bad, because contributors must install Bun, either directly or through mise (ADR 0015).
- Bad, because Bun's isolated linker exposes undeclared dependencies that a hoisted layout would hide, so each package must list what it imports.
