# Manage users from an admin panel with Better Auth's admin plugin

## Context and Problem Statement

Every user has a role (`user` or `admin`, [ADR 0024](0024-role-based-access-control.md)), but promoting a user, or getting rid of one, meant editing the database by hand.
Admins need a page, behind authentication, that lists users and lets them change a user's role, block them, or remove them.
Blocking has to hold: a blocked user must be signed out of every session and refused at the next sign-in, not only hidden from the page.
The feature code must stay behind the authentication port so the vendor can still be swapped.

## Considered Options

- Better Auth's `admin` plugin, behind new methods on the authentication port
- Hand-written Drizzle queries in the app, plus a sign-in hook that refuses blocked users
- A separate `user-management` capability next to `authentication`

## Decision Outcome

Chosen option: "Better Auth's `admin` plugin, behind new methods on the authentication port", because blocking is only real if the sign-in path enforces it, and the plugin already does that: it refuses to create a session for a banned user and deletes their sessions when they are banned.
Removing a user through it also deletes their sessions and sign-in accounts in the right order for the foreign keys.

The port gains `getCurrentUser`, `listUsers`, `setUserRole`, `blockUser`, `unblockUser` and `removeUser`, expressed with the `User` entity.
They live on `Authentication` rather than a separate capability because they need the signed-in session and the sign-in path of the same vendor.
Each refuses with a `UserAdministrationError` (`forbidden`, `self`, `not-found`, `unavailable`) instead of the vendor's error, and the contract suite checks the behaviour for every vendor.

The entity calls a ban a block: `User` gains `blocked`, `blockReason` and `blockExpiresAt`, and the plugin's `banned`, `banReason` and `banExpires` fields are mapped onto those drizzle columns.
The plugin also needs `sessions.impersonated_by`.

The plugin's default admin role may impersonate users and set their passwords, and its endpoints are mounted under `/api/auth/admin`.
The access control in `better-auth/auth.ts` grants admins only what the panel uses: list, get, set role, ban and delete users, and revoke sessions.

Admins cannot change their own role, block or remove themselves, so the application cannot lose its last admin from the panel.
The first admin is still promoted in the database (see [Manage users](../how-to/manage-users.md)).

### Consequences

- Good, because blocking signs the user out everywhere and stops their next sign-in, enforced by the vendor rather than by the page.
- Good, because feature code depends only on the port and the `User` entity; another vendor implements the same six methods and passes the same contract suite.
- Good, because the Server Actions are checked twice: the adapter refuses anyone but an admin, and the plugin checks the role again on its side.
- Bad, because the plugin's endpoints are reachable over HTTP under `/api/auth/admin`, so the access control list is now part of the security surface.
- Bad, because `listUsers` returns every user in one page; a large user base will need pagination on the port.
- Bad, because a user can hold only one role, as before; finer permissions need another decision.
