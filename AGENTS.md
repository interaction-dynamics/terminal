# Ship it

Boilerplate for modern web projects: a Bun workspaces + Turborepo monorepo.

- `apps/web` — Next.js App Router application (has its own `AGENTS.md`).
- `infrastructure/adapters` — vendor adapters behind ports, imported as `@ship-it/adapters/<capability>`.
- `domain/entities` — domain entities validated with Zod, imported as `@ship-it/entities`.
- `config/typescript` — shared TypeScript configuration.

## Read first

- `.docs/architecture/overview.md` — system shape and where new code belongs. Read it before any significant change.
- `.agents/rules/` — project rules (architecture, Next.js, UI, commits, decision records, feature specs, feature layout). Follow every rule that applies to your change. Claude Code loads them automatically through `.claude/rules`; other agents must read them.
- `.agents/skills/` — step-by-step skills for recurring tasks (adapters, Drizzle schema changes, commits and PRs, client changelogs, rebranding a project created from this boilerplate, frontend design with tasteskill (`design-taste-frontend`, ADR 0050), and the features-cli skills for creating, moving, documenting and validating features).
- `.docs/decisions/` — MADR decision records. Record every new technical choice there, using the next free number.
- `specs/` — Spec Kit feature specs. Store every behaviour asked for in a prompt there before writing the code (`.agents/rules/feature-specs.md`).

## Split the code by feature

Split the code by feature as much as possible: every piece of code that belongs to one feature lives in that feature's folder, with a `README.md` (owner, title, one-line description).

- A route folder that isolates one feature (admin, checkout) is the feature: add a `README.md` with `feature: true` and keep its code in `_components/`, `_use-cases/` and `actions.ts`.
- A feature used by several routes, a composition page, a layout or an adapter goes in `apps/web/src/features/<feature>/`.
- Composition pages (the landing page, layouts) are never features: they stay thin and render features and shared components.
- `components/`, `lib/` and `config/` only hold code shared by several features.

`.agents/rules/feature-layout.md` has the full rule; follow it on every code change.

- Start a task by mapping the features with the `explore-features` skill: `bunx features scan apps/web/src --json --skip-changes`.
- New feature, page or capability: use the `create-feature` skill.
- Changing code that is not in a feature yet: make it a feature first (README or `extract-feature` skill), in its own commit.
- Before committing: `validate-features` skill and `bun run check-features`.
- Before opening a pull request: `bunx features diff apps/web/src --since origin/master`, and list the features and owners touched in the description.

## Commands

Run from the repository root:

| Command                            | Purpose                                                                                                |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `bun install`                      | Install dependencies and Git hooks                                                                     |
| `bun dev`                          | Start every app in development mode                                                                    |
| `bun run lint`                     | Lint with oxlint                                                                                       |
| `bun run format`                   | Check formatting with oxfmt (`bun run format:fix` to write)                                            |
| `bun run check-types`              | Type-check every workspace                                                                             |
| `bun run test:ci`                  | Run unit tests once (`bun run test` watches; plain `bun test` runs Bun's own runner, not these suites) |
| `bun run build`                    | Build every workspace                                                                                  |
| `bun run check-adr-numbers`        | Fail on duplicate decision record numbers                                                              |
| `bun run check-auth-schema`        | Fail when the Drizzle auth tables cannot hold what Better Auth writes (no database needed)             |
| `bun run check-spec-numbers`       | Fail on duplicate feature spec numbers in `specs/`                                                     |
| `bun run check-features`           | Validate the feature folders of `apps/web/src` with features-cli (duplicate names, broken records)     |
| `bunx features serve apps/web/src` | Browse the features, owners, specs and decisions in a local dashboard                                  |

End-to-end tests run against a production build: `bun run build`, then `bun run test:e2e` in `apps/web`.

Before pushing, run `bun install && bun run format`.

## CLIs

Operations outside the code use these CLIs; install and sign in once per machine.
`.docs/how-to/deploy-to-vercel.md` has the full deployment setup and the non-interactive gotchas.

| CLI                                 | Install                 | Sign in                               | Use it for                                                               |
| ----------------------------------- | ----------------------- | ------------------------------------- | ------------------------------------------------------------------------ |
| GitHub CLI (`gh`)                   | `brew install gh`       | `gh auth login`                       | Pull requests, CI checks and logs (`.agents/rules/pr-watching.md`)       |
| Vercel CLI (`vercel`)               | `bun add -g vercel`     | `vercel login`                        | Link the project (Root Directory `apps/web`), env vars, domains, deploys |
| Resend CLI (`resend`, `resend-cli`) | `bun add -g resend-cli` | `resend login --web --profile <name>` | Sending domains, DNS records, scoped API keys for the email adapter      |

<!-- BEGIN:turborepo-agent-rules -->

# This is NOT the Turborepo you know

Turborepo configuration, task behavior, and CLI commands can vary between installed versions and may differ from your training data. Resolve the `turbo` package from this file's directory or relevant workspace; in monorepos, it may not be visible from the repository root. For example, run `node -p "require.resolve('turbo/package.json')"` from a workspace that depends on `turbo`.

Read `docs/README.md` inside that installed package first, then read the relevant pages from its `docs/` directory before changing Turborepo configuration or commands. Heed deprecation notices. These bundled docs match the installed package version and are available without network access.

This block is written and re-added by `turbo` before repository-scoped commands when an AI agent is detected. In the Turborepo source repository, its template is defined in `crates/turborepo-cli/src/cli/agent_guidance.rs`. Removing the managed block while updates are enabled means a later qualifying invocation will add it again. Set `"agentGuidance": false` in the root `turbo.json` or `turbo.jsonc` to opt out; this does not remove an existing block. Keep the block committed with your work to avoid an uncommitted change on the next agent invocation.
<!-- END:turborepo-agent-rules -->
