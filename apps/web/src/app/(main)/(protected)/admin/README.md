---
feature: true
# TODO: owner
creation_date: 2026-11-19
---

# User administration

Lets an administrator list users, block or unblock them, change their role and remove them.

## How it works

- `/admin` (`page.tsx`) is reserved to administrators (`forbidden()` otherwise) and renders `UsersTable` and `UserActions` (`_components/`).
- The Server Actions in `actions.ts` validate their input and call the authentication adapter, which refuses every call unless the caller is a signed-in administrator.
- Decision: [ADR 0042, manage users from an admin panel](../../../../../../../.docs/decisions/0042-manage-users-from-an-admin-panel.md).
