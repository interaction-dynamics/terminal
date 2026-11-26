# Validate environment variables with typed schemas from t3-env

## Context and Problem Statement

About 23 environment variables were read as raw `process.env.*` strings across 24 files in `apps/web` and `infrastructure/adapters`.
Nothing listed which variables exist, which are client-side, or what shape they must have.
Typos and malformed values (a webhook that is not a URL, a Hotjar id that is not a number) only surfaced at runtime, and non-null assertions such as `process.env.DATABASE_URL!` hid missing values from the compiler.
Adapters choose their vendor from these variables, so whatever replaces the raw reads must keep the fail-closed behaviour of [ADR 0021](./0021-fail-closed-authentication-and-complete-email-providers.md): a vendor that is not configured falls back to its blank adapter, and the app still builds and runs with nothing set.

How should variables be declared, validated and read, and who owns each schema?

## Considered Options

- Keep raw `process.env` reads and document the variables in `.env.local.example`.
- A hand-written Zod schema parsed once in `apps/web`.
- `@t3-oss/env-nextjs` schemas, one per capability in `@ship-it/adapters`, composed in `apps/web`.
- Schemas parsed once into module-level constants, or getters that parse on each call.
- Variables optional with blank fallbacks, or required with `skipValidation` for CI builds.

## Decision Outcome

Chosen options:

- `@t3-oss/env-nextjs` with Zod 4, because it separates server and `NEXT_PUBLIC_` client variables by type, throws when server variables are read in the browser, and wires client variables so Next.js can still inline them.
  A hand-written schema would have to reimplement those three things.
- One `env.ts` per capability folder in `infrastructure/adapters/src`, because the hexagonal layout says each capability owns its integration, and its variables are part of it.
  Vendors of one capability share a schema because the capability's `index` reads all of them to pick a provider.
  `@ship-it/adapters/env` re-exports them, and `apps/web/src/config/env.ts` composes them with `extends` and adds the variables the app owns (`NODE_ENV`).
- `next.config.ts` imports the composed env, because that validates every variable when the app builds or starts instead of on the first request that happens to use it.
- Each capability exports a getter (`emailEnv()`) rather than a constant, because adapters choose providers and read senders when called, as the raw reads did, and the adapter unit tests stub variables between calls.
  Parsing a handful of optional strings on each call is negligible.
- Every vendor variable is optional and `skipValidation` is not used, because an unset variable must disable its vendor, not fail the build (ADR 0021).
  The `Validate Code` and end-to-end CI jobs build with no secrets and pass validation as-is; `skipValidation` would only hide the malformed values the schema exists to catch.
  Empty strings count as unset (`emptyStringAsUndefined`), matching `.env.local.example`, which lists every variable with an empty value.
- Values that are set must be well formed: URLs for `DATABASE_URL`, `BETTER_AUTH_URL`, `SLACK_WEBHOOK_URL` and `NEXT_PUBLIC_POSTHOG_HOST`, and digits for `NEXT_PUBLIC_HOTJAR_ID`, which is interpolated into an inline script.
- Axiom is selected only when both `NEXT_PUBLIC_AXIOM_TOKEN` and `NEXT_PUBLIC_AXIOM_DATASET` are set, because a token without a dataset used to load Axiom with an undefined dataset; it now falls back to the blank provider like any other incomplete vendor.

### Consequences

- Good, because every variable, its side (server, client or shared) and its format is declared in one schema per capability, next to the code that uses it.
- Good, because a malformed value fails `next build` and `next dev` with the variable's name, instead of failing at runtime.
- Good, because reading a server secret from a client component throws instead of silently returning `undefined`.
- Good, because CI and fresh clones still build with no environment at all.
- Bad, because a malformed optional value now stops the build, where it used to break only the vendor that read it.
- Bad, because client variables must be listed twice in their schema file (in `client` and in `experimental__runtimeEnv`) so Next.js can inline them.
- Bad, because cross-variable rules, such as `DATABASE_URL` being needed once an authentication secret is set, are still enforced where the variable is used rather than in the schema.
- Neutral, because `process.env` is still read by tool configs outside the app and adapters source (`playwright.config.ts`, `drizzle.config.ts`), which run outside Next.js.
