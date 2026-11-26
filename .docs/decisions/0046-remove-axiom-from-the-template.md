# Remove Axiom from the Template

Supersedes [ADR 0010](0010-use-axiom-for-monitoring.md).

## Context and Problem Statement

ADR 0010 added Axiom (`@axiomhq/js`, `@axiomhq/logging`, `@axiomhq/nextjs`, `@axiomhq/react`) as the monitoring vendor behind the `monitoring` adapter.
Projects created from this template rarely configured it: without `NEXT_PUBLIC_AXIOM_TOKEN` and `NEXT_PUBLIC_AXIOM_DATASET` the adapter fell back to the blank provider anyway.
Keeping it costs four dependencies, two client-side environment variables, a contract test, and a vendor dataset to rename on every rebrand.
Should the template keep shipping a log vendor by default?

## Considered Options

- Keep Axiom as the default monitoring vendor
- Remove Axiom and keep the blank provider plus `@vercel/otel` tracing
- Replace Axiom with another log vendor

## Decision Outcome

Chosen option: "Remove Axiom and keep the blank provider plus `@vercel/otel` tracing", because the template should not impose a log vendor that most projects never set up, and the `monitoring` port stays in place so a project can add the vendor it needs.

`monitoring/client` and `monitoring/server` now re-export the blank provider (`console.error` for errors, no Web Vitals reporting, no request logging).
OpenTelemetry tracing through `monitoring/telemetry` is unchanged.

### Consequences

- Good, because the template drops four dependencies and two `NEXT_PUBLIC_` variables.
- Good, because the `monitoring` port and its contract suite remain, so adding a vendor is a new subfolder plus a provider switch in `client/index.ts` and `server/index.ts`.
- Bad, because projects lose structured log shipping and Web Vitals reporting out of the box; errors only reach the host's console logs.
- Bad, because a project that relied on Axiom must restore the adapter from history before upgrading.
