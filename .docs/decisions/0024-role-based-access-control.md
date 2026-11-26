# Role-based access control with a `role` field on User

## Context and Problem Statement

The application needs to restrict access to certain pages (starting with the dashboard) to administrators only.
No authorization layer existed — all authenticated users had equal access to every protected route.

## Considered Options

- Add a `role` field directly to the User entity and database schema
- Use a separate `roles` table with a many-to-many join
- Delegate roles entirely to the auth provider (Clerk roles, NextAuth JWT claims)

## Decision Outcome

Chosen option: "Add a `role` field directly to the User entity and database schema", because it is the simplest model
that satisfies the current requirement (distinguishing `user` from `admin`), keeps the role co-located with the user
record, and mirrors the field already supported by better-auth's `additionalFields` API.

The `isAdmin()` helper is placed behind the authentication adapter port so every provider (better-auth, Clerk,
NextAuth, blank) can implement it without leaking provider internals into feature code.

### Consequences

- Good, because adding a new role is a one-line enum change in the entity and a schema migration.
- Good, because feature code depends only on `isAdmin()` from the auth port, not on any provider SDK.
- Bad, because a single `role` column does not scale to fine-grained permissions without a schema migration.
- Bad, because promoting a user to admin currently requires a direct database update (no admin UI yet).
