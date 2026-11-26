# Set Up the Turborepo Remote Cache

Turborepo caches task results on disk in `.turbo/cache`.
Linked git worktrees, such as the ones agent sessions run in, share the main worktree's cache automatically.
A Remote Cache extends that to other machines and to CI, so a build done once anywhere is a cache hit everywhere.

Nothing in this repository enables a Remote Cache by default, and no credentials are committed.
`.turbo/` is git-ignored, so the files written by the commands below stay local.

## Vercel Remote Cache (local development)

Vercel's Remote Cache is free on all plans, even if the app is not hosted on Vercel.

1. Authenticate the Turborepo CLI. The token is stored in your user config, not in the repository.

   ```bash
   bunx turbo login
   ```

   If your Vercel team uses single sign-on, use `bunx turbo login --sso-team=<team-slug>` instead.

2. Link this repository to a team's cache. This writes `.turbo/config.json`, which is git-ignored.

   ```bash
   bunx turbo link
   ```

3. Verify: run a build, delete the local cache, and run it again.
   The second run should replay from the Remote Cache instead of executing.

   ```bash
   bun run build
   rm -rf .turbo/cache
   bun run build
   ```

   In a linked worktree the local cache lives in the main worktree's `.turbo/cache`.

To stop using it, run `bunx turbo unlink`.

## CI and other non-interactive environments

Instead of `turbo login`, set these environment variables as secrets in the CI provider:

- `TURBO_TOKEN`: a Vercel access token with access to the team.
- `TURBO_TEAM`: the team slug.

Self-hosted caches that implement the Turborepo Remote Cache API also need `TURBO_API`, the base URL of the server.
Never commit these values or write them to `turbo.json`.

The `Validate Code` workflow does not set them today; adding them is a separate change.

## Signing artifacts

To reject tampered artifacts, set `"remoteCache": { "signature": true }` in `turbo.json` and provide the secret key in `TURBO_REMOTE_CACHE_SIGNATURE_KEY` on every machine that reads or writes the cache.
Artifacts that fail verification are treated as cache misses.

## Things to check before enabling it for a team

- `turbo.json` uses `"envMode": "loose"`, so environment variables are not part of task hashes unless a task lists them in `env`.
  Turborepo's Next.js framework inference adds `NEXT_PUBLIC_*` variables automatically, but other build-time variables are not, and two machines with different values would share a cached build.
  Declare any variable that changes build output in the task's `env` first.
- Turborepo stores task logs as artifacts, so do not print secrets from build or test scripts.

## Effect on the pre-push hook

The agent pre-push hook (`.agents/hooks/prepush-check.ts`, see ADR 0033) runs `turbo run build check-types test:ci --affected`.
With a Remote Cache, those tasks are cache hits whenever CI or a teammate already ran them for the same inputs, which removes most of the remaining wait on a fresh machine.

For details, see the installed Turborepo docs in `node_modules/turbo/docs/core-concepts/remote-caching.mdx`.
