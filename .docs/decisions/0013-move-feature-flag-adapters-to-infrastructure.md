# Move feature flag adapters to the infrastructure package

## Context and Problem Statement

The PostHog, Vercel and Statsig flag SDKs were imported directly by `apps/web/src/config/flags.ts`, which also held the environment variable checks deciding whether each provider was usable.
That put vendor knowledge in feature code, contradicting the hexagonal architecture rules, and it meant adding a fourth provider — or dropping one — required editing the file that declares the flags.
Each provider also fails differently when unconfigured, so the checks had to be written against vendor behaviour that the application layer should not have to know about.

## Considered Options

- Move each provider behind an `experimentation` capability folder in `infrastructure/adapters`, following the `authentication` and `email` precedent
- Keep the adapters in `apps/web` and extract only the environment variable checks into helpers
- Keep everything in `apps/web/src/config/flags.ts` and rely on the existing inline checks

## Decision Outcome

Chosen option: "move each provider behind an `experimentation` capability folder", because it is the arrangement the repository already uses for authentication and email, and it is the only option that stops vendor SDKs from being imported by feature code.

Each vendor subfolder exports a `create*Adapter(fallback)` factory that owns the environment variable check for its own provider and returns the vendor adapter when configured, or the `blank` adapter — which keeps the flag's declared default value — when it is not.
`apps/web/src/config/flags.ts` is reduced to flag declarations that import from `@ship-it/adapters/experimentation` and no longer name a vendor.

The port is `Pick<Adapter<boolean, never>, 'decide'>`.
Only `decide` is part of the contract because each provider identifies its audience with its own shape — a PostHog distinct id, a Statsig user — and exposing any of them would leak a vendor type through the boundary and stop the implementations being interchangeable.

### Consequences

- Good, because a flag provider can be swapped, added or removed without touching the flag declarations.
- Good, because each provider's "am I configured?" rule sits next to the SDK whose failure mode it exists to avoid.
- Good, because the `@flags-sdk/*` packages are dependencies of the infrastructure package only, so the boundary is enforced by the dependency graph rather than by convention.
- Bad, because the port only covers boolean flags; string, number and JSON flags would need it widened.
- Bad, because dropping entities from the port means a provider cannot be given a user to decide against until the port grows a domain-typed identity, so provider-side targeting rules cannot be used yet.
