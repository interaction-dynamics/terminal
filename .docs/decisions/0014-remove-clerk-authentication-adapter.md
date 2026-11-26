# Remove the Clerk Authentication Adapter

## Context and Problem Statement

Clerk was the first authentication provider, and it was later replaced first by next-auth and then by Better Auth.
The Clerk adapter stayed in `infrastructure/adapters/src/authentication/clerk` and was still selected first whenever `CLERK_SECRET_KEY` was set.
That left a paid vendor SDK in two `package.json` files for a provider the project no longer intends to use.
It also meant a stray `CLERK_SECRET_KEY` silently took precedence over Better Auth.
Should the adapter stay available as an interchangeable option, or be removed?

## Considered Options

- Keep the Clerk adapter as an optional provider
- Remove the Clerk adapter and its dependency
- Remove the Clerk adapter and fail at startup when `CLERK_SECRET_KEY` is still set

## Decision Outcome

Chosen option: "Remove the Clerk adapter and its dependency", because Better Auth already covers the project's authentication needs and the adapter boundary makes the removal a change confined to the authentication capability folder.
Failing at startup was rejected because a leftover environment variable is harmless once nothing reads it.

### Consequences

- Good, because `@clerk/nextjs` and its transitive dependencies leave the install and the bundle.
- Good, because provider selection now has one less branch, and Better Auth is selected first.
- Good, because the authentication port no longer has to accommodate a vendor the project does not use.
- Bad, because a deployment configured only with `CLERK_SECRET_KEY` falls through to the blank adapter, so sign-in stops working until `BETTER_AUTH_SECRET` or `AUTH_SECRET` is set.
- Bad, because reintroducing Clerk later means restoring the adapter from git history.
- The `/.clerk/` rules stay in `.gitignore` and `apps/web/.gitignore`, because existing checkouts can hold Clerk keyless credentials in that folder.
