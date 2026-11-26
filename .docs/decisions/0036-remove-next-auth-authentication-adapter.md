# Remove the next-auth Authentication Adapter

## Context and Problem Statement

[ADR 0011](./0011-use-better-auth-instead-of-next-auth.md) replaced next-auth (Auth.js) with Better Auth, but the next-auth adapter stayed in `infrastructure/adapters/src/authentication/next-auth`.
It was still selected whenever `AUTH_SECRET` was set without `BETTER_AUTH_SECRET`, and the `/api/auth/*` route fell back to its handlers whenever `BETTER_AUTH_SECRET` was unset.
That kept `next-auth` on a `beta` tag and `@auth/neon-adapter` in the install, plus a hand-written SQL schema that the Drizzle migrations did not own.
Should the adapter stay available as an interchangeable option, or be removed as the Clerk adapter was in [ADR 0014](./0014-remove-clerk-authentication-adapter.md)?

## Considered Options

- Keep the next-auth adapter as an optional provider
- Remove the next-auth adapter and its dependencies
- Remove the adapter and select Better Auth when only `AUTH_SECRET` is set

## Decision Outcome

Chosen option: "Remove the next-auth adapter and its dependencies", because Better Auth already covers the project's authentication needs and the adapter boundary confines the removal to the authentication capability folder and the auth route.
Selecting Better Auth from `AUTH_SECRET` was rejected because Better Auth uses different tables, so an existing Auth.js deployment would fail at its first query rather than at configuration time.

The `/api/auth/[...nextauth]` route is renamed `/api/auth/[...all]` and answers 404 when `BETTER_AUTH_SECRET` is unset, since no handler is left to serve it.

### Consequences

- Good, because `next-auth`, its `beta` tag, and `@auth/neon-adapter` leave the install and the bundle.
- Good, because provider selection now has a single vendor branch and the blank fallback.
- Good, because the hand-written `schema.sql` that drifted from the Drizzle schema is gone.
- Bad, because a deployment configured only with `AUTH_SECRET` falls through to the blank adapter, so protected routes redirect to the login page and sign-in stops working until `BETTER_AUTH_SECRET` is set.
- Bad, because Auth.js tables left in an existing database are no longer used and must be dropped by hand.
- Bad, because reintroducing next-auth later means restoring the adapter from git history.
