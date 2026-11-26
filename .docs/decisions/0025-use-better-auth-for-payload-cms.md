# Use better-auth for Payload CMS admin authentication

## Context and Problem Statement

Payload CMS ships with its own email/password authentication for the admin panel.
The app already uses better-auth (with email OTP) as its primary auth system.
Having two separate credential systems means users must maintain separate accounts
and developers must reason about two independent session stores.

## Considered Options

- Keep Payload's built-in auth separate from better-auth
- Replace Payload's auth with a custom strategy backed by better-auth sessions
- Use Payload's API key auth for programmatic access only, disable the admin login

## Decision Outcome

Chosen option: "Replace Payload's auth with a custom strategy backed by better-auth sessions",
because it unifies the auth surface to a single credential store and lets admins reach
the CMS with the same OTP flow used everywhere else in the app.

### Consequences

- Good, because admins use one login flow for the whole product.
- Good, because better-auth's session is already validated by the Next.js middleware,
  so unauthenticated requests to `/studio-2` are rejected before they reach Payload.
- Good, because Payload user records are auto-provisioned on first access, so there
  is no separate user-management step.
- Bad, because Payload's local auth strategy (password reset, email verification) is
  disabled and those features are no longer available through the CMS admin.
- Bad, because the Payload login page at `/studio-2/login` becomes unreachable; users
  who navigate there directly are redirected to `/login` by the middleware.
