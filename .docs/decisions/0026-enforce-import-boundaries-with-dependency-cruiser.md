# Enforce hexagonal import boundaries with dependency-cruiser

## Context and Problem Statement

The hexagonal architecture rule (`.agents/rules/hexagonal-architecture.md`) said feature code imports `@ship-it/adapters/<capability>`, never a vendor subfolder.
Nothing checked it.
`infrastructure/adapters/package.json` exported vendor subpaths (`./authentication/better-auth`, `./database/drizzle`) and a `./*` wildcard that made every file public.
The app already imported the Better Auth vendor folder directly, and AI agents follow what the code does, not what a prose rule says.

How do we turn the rule into a check that fails CI, without slowing everyone down?

## Considered Options

- dependency-cruiser, with rules on resolved module paths.
- oxlint `no-restricted-imports`, with one override per folder.
- `package.json` exports alone.
- A custom script that greps import specifiers.

## Decision Outcome

Chosen option: "dependency-cruiser", backed by tightened `package.json` exports.

dependency-cruiser matches the resolved file, not the specifier.
So `../../email/resend`, `@ship-it/adapters/email/resend` and an `@/` alias all hit the same rule, and a vendor SDK is recognised whether it is imported by its root or a deep path such as `better-auth/next-js`.
Its rules capture groups from the importer path, which expresses "an adapter may reach freely into its own capability, and into others only through their entry point" as one rule.
oxlint `no-restricted-imports` only sees specifiers, so each vendor folder would need its own override and relative paths would slip through.
The oxlint config is also being reworked in parallel (ADR 0029), and keeping this in its own file avoids coupling the two.
Exports alone stop other packages resolving a vendor subpath, but say nothing about vendor SDKs, entities, or imports inside the adapters package.
A grep script would re-implement module resolution badly.

### Rules

- `app-imports-capability-only`: `apps/**` may only reach a capability entry point under `infrastructure/adapters/src`.
- `cross-capability-through-entry-point`: an adapter may import its own capability folder freely, and other capabilities only through their entry point.
- `entities-stay-pure`: `domain/entities` must not import the app, the adapters or drizzle.
- `vendor-sdk-confined:<sdk>`: each vendor SDK only inside its vendor subfolder(s), from the `VENDOR_SDKS` map in `.config/dependency-cruiser.cjs`.
- `no-unresolvable`: an import the resolver cannot follow fails the check, so a broken alias cannot silently disable the other rules.

### Entry points

A capability entry point is `<capability>/index.ts(x)`, `<capability>/interfaces.ts` or `<capability>/wrappers.ts`, plus `monitoring/client`, `monitoring/server` and `monitoring/telemetry`.
The monitoring subpaths are entry points, not vendors: each targets one runtime (browser bundle, request path, instrumentation hook) and picks the vendor itself, and merging them would pull server code into the browser bundle.
`wrappers.ts` is the build-time entry point `next.config.ts` needs for `content-management` and `dev-tools`.
`src/env.ts` (`@ship-it/adapters/env`) is an entry point too: it composes each capability's env schema for the app (ADR 0027) and loads no vendor SDK.

### No wiring exception

`apps/web/src/adapters/**` gets no exemption.
Its only vendor import loaded the Better Auth route handlers when `BETTER_AUTH_SECRET` is set, which is the vendor selection the capability folder already does for `getProvider`.
That selection, and the 404 fallback when no provider is configured, moved into `getRouteHandlers` on `@ship-it/adapters/authentication`, so the app needs no vendor import at all.

### Exports

`infrastructure/adapters/package.json` now exports only the entry points above.
`./authentication/better-auth`, `./database/drizzle` and the `./*` wildcard are gone.
`./database` is the new entry point, re-exporting the Drizzle client and schema for `better-auth`, whose Drizzle adapter needs that client.

### Exempt packages

`next` and `react` are the framework, and React-only libraries such as `@react-email/components` are exempt by the rule itself.
`flags` is exempt because it is the experimentation port the app codes against (ADR 0002), and the vendor-specific `@flags-sdk/*` packages stay confined.

### Consequences

- Good, because the rule is checked on every PR (`bun run lint:boundaries` in `validate.yml`) and fails with a message that says what to do instead.
- Good, because it runs in about two seconds over the whole repo, so the pre-push hook can run it too.
- Good, because adding a vendor now means adding one line to `VENDOR_SDKS`, which also documents where that SDK lives.
- Bad, because dependency-cruiser cannot use TypeScript 7 as a parser yet, so it parses with `@swc/core`, an extra native dev dependency that nothing imports (listed in knip's `ignoreDependencies`).
  Type-only imports are still checked.
- Bad, because dependency-cruiser needs Node 22, 24 or 26+; the Node 26 pinned in `mise.toml` and CI is fine, but Node 23 is not.
- Bad, because the `database` port still exposes a Drizzle client.
  Making it vendor-neutral is a separate change.
