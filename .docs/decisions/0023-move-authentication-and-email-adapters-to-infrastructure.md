# Move authentication and email adapters to the infrastructure package

## Context and Problem Statement

The hexagonal architecture rules for this repository specify that adapters for external systems (authentication providers, email vendors) should live in `infrastructure/adapters/src/<capability>`.
The `authentication` and `email` capability adapters were located in `apps/web/src/adapters/` instead, mixing infrastructure concerns into the application layer.
Vendors could not be swapped without changes spread across the application.

## Considered Options

- Move adapters as-is and resolve `@/` path dependencies via dependency injection (factory pattern)
- Move adapters as-is and use a runtime configuration registry (mutable singleton)
- Keep adapters in `apps/web` and only extract shared interfaces to infrastructure

## Decision Outcome

Chosen option: "factory pattern", because it is explicit, type-safe, and easy to test in isolation.
Each vendor implementation exposes a `create*Adapter(config)` factory that accepts `protectedRoutes` and an optional `LoginFormComponent`.
The `apps/web/src/adapters/authentication/` and `apps/web/src/adapters/email/` folders are reduced to thin wrappers that supply the app-specific configuration and re-export the result.

### Consequences

- Good, because vendor authentication and email implementations can now be swapped without touching any feature code.
- Good, because the infrastructure package is the single source of truth for adapter logic.
- Good, because the factory signature documents exactly which app-specific dependencies each adapter requires.
- Bad, because each apps/web wrapper must import `protectedRoutes` and `BaseLoginForm` and pass them to the factory, adding a small amount of indirection.
- Bad, because the infrastructure package now depends on React and Next.js, making it a Next.js-aware infrastructure layer rather than a framework-agnostic one.
