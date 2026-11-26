# Use Better Auth Instead of next-auth for Authentication

## Context and Problem Statement

next-auth (Auth.js) was chosen to replace Clerk, giving full control over authentication without an external paid service.
However, next-auth's magic-link flow requires only an email provider and returns no OTP code the user can type — the user must open their inbox and click a link.
We want an authentication experience closer to what modern apps use: a short numeric code the user enters on the same page without leaving the app.
Better Auth is an open-source, self-hosted authentication library that supports email OTP out of the box, integrates directly with Drizzle (already used in the project), and provides a richer plugin system for future capabilities such as passkeys, social login, and MFA.

## Considered Options

- next-auth (Auth.js) with Resend magic-link provider
- Better Auth with email OTP plugin
- Lucia Auth

## Decision Outcome

Chosen option: "Better Auth with email OTP plugin", because it delivers a native OTP code flow without leaving the app, integrates directly with the existing Drizzle schema, and offers a first-class plugin system that covers likely future needs (passkeys, OAuth, MFA) without requiring a third-party dashboard.

### Consequences

- Good, because users receive a short numeric code and complete sign-in on the same page, removing the friction of switching to an email client.
- Good, because the Drizzle adapter reuses the existing database schema and migrations toolchain — no separate SQL schema or adapter package is needed.
- Good, because Better Auth's plugin system makes it straightforward to add OAuth providers, passkeys, or MFA later without rewiring the authentication layer.
- Good, because the adapter boundary already in place means swapping the underlying library requires changes only inside `apps/web/src/adapters/authentication/better-auth/`.
- Bad, because Better Auth is a newer library with a smaller ecosystem and community than Auth.js, so edge-cases may be less documented.
- Bad, because migrating existing next-auth sessions requires a data migration for any live deployment that already has users signed in.
