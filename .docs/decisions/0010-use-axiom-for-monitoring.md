# Use Axiom for Monitoring and Observability

Superseded by [ADR 0046](0046-remove-axiom-from-the-template.md).

## Context and Problem Statement

The boilerplate uses Vercel's built-in telemetry via `@vercel/otel` for OpenTelemetry traces. While this works well on Vercel, it creates a tight coupling to the Vercel platform — logs and traces are only visible through the Vercel dashboard, and the solution does not port to other hosting providers. We need a monitoring solution that provides structured logging, request tracing, and error tracking regardless of where the app is deployed.

## Considered Options

- Vercel Telemetry (`@vercel/otel`)
- Axiom (`@axiomhq/nextjs`)
- Datadog
- Sentry
- LogDNA / Mezmo

## Decision Outcome

Chosen option: "Axiom (`@axiomhq/nextjs`)", because it integrates natively with Next.js, works across any hosting provider, and has a generous free tier suitable for early-stage projects. It captures structured logs, request traces, Web Vitals, and error events through a single library without requiring a complex infrastructure setup.

### Consequences

- Good, because monitoring works independently of the deployment platform — not locked to Vercel.
- Good, because `@axiomhq/nextjs` provides first-class integration for middleware, server components, client components, API routes, and error instrumentation with minimal boilerplate.
- Good, because Web Vitals are captured automatically on the client and correlated with server-side logs in the same dataset.
- Good, because the adapter pattern keeps Axiom optional — projects without `NEXT_PUBLIC_AXIOM_TOKEN` fall back to `console.error` with no behavior change.
- Bad, because log data is stored on Axiom's servers (cloud), which may not suit projects with strict data residency requirements.
- Bad, because adding a new external service increases the number of accounts and credentials to manage when bootstrapping a project.
