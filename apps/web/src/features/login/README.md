---
# TODO: owner
creation_date: 2026-06-03
---

# Login

Lets a visitor sign in with a one-time code or a magic link sent to their email.

## How it works

- `BaseLoginForm` (public API in `index.ts`) asks for an email, then either a 6-digit code (`otp` variant) or tells the visitor to check their inbox (`magic-link` variant).
- It is vendor-neutral: the authentication adapter wrapper (`apps/web/src/adapters/authentication`) passes it to the configured provider, which supplies `onSend` and `onVerify` and renders it as `LoginForm` on the `/login` page.
