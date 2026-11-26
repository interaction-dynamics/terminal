# Drop the apps/web email wrapper

## Context and Problem Statement

ADR 0023 moved the authentication and email adapters to `infrastructure/adapters` and left `apps/web/src/adapters/authentication` and `apps/web/src/adapters/email` as thin wrappers "that supply the app-specific configuration and re-export the result".
The authentication wrapper does that: it passes `protectedRoutes` and `BaseLoginForm`, which the infrastructure package cannot import from `@/`.
The email wrapper never did.
The email provider is chosen from environment variables inside `@ship-it/adapters/email`, so the wrapper only re-exported a subset of that module (`sendEmail`, `sendFormattedEmail`, `getProvider`, `Email`).
It hid `isEmailConfigured` and the other port types, so a caller needing them would import from two places for one capability.
Only two use cases in `apps/web` imported it, while the better-auth adapter already imported `@ship-it/adapters/email` directly.

Should `apps/web` keep a wrapper for a capability that needs no app-specific configuration?

## Considered Options

- Delete the email wrapper and import `@ship-it/adapters/email` directly
- Keep the wrapper and widen it to re-export the whole module
- Keep the wrapper as it is

## Decision Outcome

Chosen option: "Delete the email wrapper and import `@ship-it/adapters/email` directly", because the wrapper bound no configuration, and the capability folder `@ship-it/adapters/email` is already the public boundary that the hexagonal architecture rule names.
An `apps/web` wrapper exists only when the app must inject something into the adapter.
This partly supersedes ADR 0023 for email; the authentication wrapper stays.

### Consequences

- Good, because there is one import path for email in the whole repository.
- Good, because callers see the full port, including `isEmailConfigured`.
- Good, because the architecture overview no longer claims the email wrapper binds config.
- Bad, because if the app later needs to inject email config (a default sender, branded templates), a wrapper or factory has to be reintroduced and the call sites repointed.
