# Move the remaining adapters to the infrastructure package and keep translation in the app

## Context and Problem Statement

ADR 0013 and ADR 0023 moved authentication, email and feature flags to `infrastructure/adapters`, and left seven capabilities in `apps/web/src/adapters`.
Those seven do not all look alike.
Some wrap a vendor SDK and could move unchanged, some are loaded by `next.config.ts`, some depend on React components from the app, and `translation` has no vendor SDK at all.
Should all seven move, and how should the ones tied to the app be handled?

## Considered Options

- Move all seven, injecting app-specific values into `translation` through a factory
- Move each capability that talks to an external system, split `content-management`, and keep `translation` in the app
- Stop here and leave the seven in `apps/web/src/adapters`

## Decision Outcome

Chosen option: "Move each capability that talks to an external system, split `content-management`, and keep `translation` in the app", because the boundary exists to contain vendors, and only `translation` has no vendor to contain.

`analytics`, `monitoring`, `notifications` and `payment` move unchanged and feature code imports them from `@ship-it/adapters/<capability>`.
They depend on Next.js and React, which the adapters package already declares.

`dev-tools` and `content-management` each publish a second subpath, `@ship-it/adapters/<capability>/wrappers`, holding the `next.config.ts` wrappers.
Next.js loads `next.config.ts` outside the bundler, so a wrapper must not import through the same entry point as a React component such as `DevToolbar`.
Keeping the wrapper in its own subpath also lets `next.config.ts` load only what it uses.

`content-management` is split because its parts have different owners.
The port, the blank provider and the `@next/mdx` wrapper move.
The MDX component map stays in `apps/web/src/mdx-components.tsx`, because Next.js requires the file there and it renders with the app's `Typography` component.
The port needs `Post`, which the adapters package cannot import from the app, so the entity moves to `@ship-it/entities`.

`translation` stays in `apps/web/src/adapters`.
It is an in-house implementation with no external system behind it: it reads `translationConfig` and the JSON files in `src/content/messages`, which belong to the app.
Its single entry point is imported by both Server and Client Components, and that only works because `server.tsx` is a `'use server'` module.
Such a module can only export async functions, so it cannot be turned into a factory, and moving it would need a wrapper for every function in the app plus a factory in the package.
That is two layers around the same code, with no vendor that could ever be swapped.

### Consequences

- Good, because every vendor SDK behind these capabilities is now a dependency of `@ship-it/adapters` only, so the dependency graph enforces the boundary.
- Good, because the direct `@vercel/toolbar/next` import in the root layout is gone.
- Good, because `Post` now lives with the other entities, and `apps/web/src/entities` no longer exists.
- Bad, because `translation` is an exception to "adapters live in `infrastructure/adapters`", and `@formatjs/intl-localematcher` and `negotiator` remain dependencies of the app.
- Bad, because `@ship-it/adapters` now requires `transpilePackages` for Server Actions and environment variable inlining in more capabilities, so it cannot be consumed outside a Next.js app without further work.
- Good, because `payment` returns domain types (`Plan`, `CheckoutSession`, `PaymentSession`) instead of Stripe objects, so feature code no longer sees Stripe and the browser no longer receives whole Stripe sessions.
- Good, because `instrumentation.ts` registers telemetry through `@ship-it/adapters/monitoring/telemetry`, a subpath of its own so `@vercel/otel` is not loaded by the proxy or by Server Actions that log errors.
