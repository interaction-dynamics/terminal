# Detect Unused Code with Knip

## Context and Problem Statement

Unused files, exports and dependencies build up in the monorepo and nothing reports them.
PR #71 removed a batch of them by hand, and the next batch would only be found the same way.
Dead code also misleads AI agents: they read an unused helper or component and copy its pattern, or keep it alive by editing it.
How should the repository catch unused code automatically, across every Bun workspace, without false positives on framework entry points?

## Considered Options

- Knip
- ts-prune / ts-unused-exports
- depcheck
- oxlint rules only
- Keep cleaning up by hand

## Decision Outcome

Chosen option: "Knip", because it is the only option that reports unused files, exports, types and dependencies in one tool, understands workspaces, and ships plugins for the frameworks this repository uses.
Its Next.js, Playwright, Vitest, Drizzle, commitlint and lefthook plugins turn each tool's file conventions and config into entry points, so `page.tsx`, `layout.tsx`, `proxy.ts`, `instrumentation.ts`, test files and config files are not reported.
The `exports` map of `@ship-it/adapters` is read as the package's entry points, so every public capability path counts as used.
ts-prune is archived and, like ts-unused-exports, only covers exports.
depcheck only covers dependencies.
oxlint works per file, so it cannot tell whether an export is imported elsewhere.
Hand cleanup is what PR #71 did, and it does not prevent the next regression.

The configuration lives in `knip.jsonc` at the repository root, so each ignore can carry a comment giving its reason.
Ignores are scoped to a file or folder and an issue type, never to a whole workspace:

- `apps/web/src/components/ui/**` keeps its exports, because shadcn/ui primitives are vendored upstream code.
- The app-level authentication and email wrappers keep their exports, because they re-export the whole port for feature code.
- `useDatetime` is kept as the client counterpart of the server `formatDatetime` helper.

The root `knip` script runs it, and the `Validate Code` workflow runs it after lint and format.

### Consequences

- Good, because a pull request that leaves a file, export or dependency unused now fails CI.
- Good, because AI agents and the pre-push hook can run `bun run knip` locally and get the same answer as CI.
- Good, because each ignore says why it exists, so a reviewer can tell an intentional public API from forgotten code.
- Bad, because the `./*` wildcard in the adapters `exports` map makes every file under `infrastructure/adapters/src` an entry point, so unused exports inside adapters are not reported until that wildcard is removed.
- Bad, because a new framework convention or a config file in a non-default location needs a matching entry in `knip.jsonc`, or it is reported as unused.
- Bad, because the CI job runs one more step, although Knip finishes in a few seconds on this repository.
- Bad, because the CI step sets `KNIP_DISABLE_RAW_TRANSFER=1`: oxc-parser's raw transfer mode reserves a multi-gigabyte buffer that the `ubuntu-slim` runner cannot allocate, so CI parses with the slower standard mode.
