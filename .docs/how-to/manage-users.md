# Manage users

Admins manage users from the admin panel at `/admin`.
See [ADR 0042](../decisions/0042-manage-users-from-an-admin-panel.md) for how it works.

## What an admin can do

| Action            | Effect                                                                               |
| ----------------- | ------------------------------------------------------------------------------------ |
| Make admin / user | Changes the user's role. Only admins can open `/admin` and `/dashboard`.             |
| Block             | Ends every session the user has open and refuses their next sign-in until unblocked. |
| Unblock           | Lets the user sign in again.                                                         |
| Remove            | Deletes the user with their sessions and sign-in accounts. It cannot be undone.      |

Admins cannot change, block or remove their own account, so the panel never leaves the application without an admin.

## Promote the first admin

Every new user signs up with the `user` role, so the first admin has to be promoted in the database.
Sign in once with the account, then run this against the database (the Neon SQL editor, or `bun run db:studio` from `infrastructure/adapters`):

```sql
UPDATE "default"."users" SET "role" = 'admin' WHERE "email" = 'you@example.com';
```

Reload the page: no new sign-in is needed, the role is read on every request.
From then on, promote other admins from `/admin`.

## Use it from code

Feature code calls the authentication port through `@/adapters/authentication`:

```ts
import { blockUser, isUserAdministrationError, listUsers } from '@/adapters/authentication';
```

Each operation rejects with a `UserAdministrationError` whose `code` is `forbidden`, `self`, `not-found` or `unavailable`.
Use `isUserAdministrationError` rather than `instanceof` to recognise it.
