# Use next-auth Instead of Clerk for Authentication

## Context and Problem Statement

Clerk was initially chosen for its developer experience, and the authentication layer was wrapped in an adapter to allow future provider changes. However, Clerk introduces an external dependency with its own pricing model that scales with monthly active users — making it harder to predict costs as the project grows. We want an authentication solution that gives us full control over pricing, user experience, and extensibility.

## Considered Options

- Clerk
- next-auth (Auth.js)
- Supabase Auth
- Firebase Auth

## Decision Outcome

Chosen option: "next-auth (Auth.js)", because it is open-source, self-hosted, and removes Clerk as an external paid service. It runs entirely within the Next.js application, reducing the number of third-party services a developer needs to configure when starting a new project from this boilerplate.

### Consequences

- Good, because pricing is fully controlled — authentication cost is only the database (Neon) and email provider (Resend), both of which are already required by the project.
- Good, because adding more providers (OAuth, magic link, credentials, passkeys) is straightforward through the Auth.js provider system without depending on a third-party dashboard.
- Good, because the user experience (sign-in pages, email templates, session handling) is fully customizable within the codebase — no external UI to configure.
- Good, because it reduces the number of external services to set up when bootstrapping a new project, lowering onboarding friction.
- Bad, because it requires more upfront implementation work compared to Clerk's drop-in UI components.
- Bad, because features like organization management, MFA, and user impersonation that Clerk provides out of the box must be built manually if needed.
