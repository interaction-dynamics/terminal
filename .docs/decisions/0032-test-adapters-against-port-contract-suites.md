# Test adapters against shared port contract suites

## Context and Problem Statement

The hexagonal architecture promises that every vendor behind a port is interchangeable, but nothing checked it.
`infrastructure/adapters` had four test files, written per vendor, so each vendor was tested against whatever its author thought of.
Agents and contributors adding or changing an adapter had no quick way to prove it still honours the port, including the fail-closed behaviour of [ADR 0021](./0021-fail-closed-authentication-and-complete-email-providers.md).

How should adapters be tested so that a vendor that drifts from its port fails in CI, without network access or vendor secrets?

## Considered Options

- Shared contract suite per port, run once per vendor with the vendor SDK mocked.
- Hand-written unit tests per vendor, as before.
- Integration tests against vendor sandboxes (Stripe test mode, Resend test keys, and so on).
- Recorded HTTP fixtures (Polly.js or MSW recordings) replayed per vendor.

## Decision Outcome

Chosen option: "Shared contract suite per port, run once per vendor with the vendor SDK mocked", because it is the only option that states the port's behaviour once and makes every vendor prove it, while running offline in `bun test:ci`.

Each capability has a `src/<capability>/<capability>.contract.ts(x)` exporting `describe<Capability>Contract(vendor, harness)`.
The suite only speaks in port terms.
Each vendor runs it from `src/<capability>/<vendor>/<vendor>.contract.test.ts(x)`, mocking its SDK with `vi.mock` and passing a harness that translates between port terms and the SDK: it seeds vendor responses from domain fixtures, reports what the SDK received in domain terms, and lists the config the vendor cannot work without.
Where an SDK's constructor validates config (Resend, Mailgun, Stripe), the mock subclasses the real client and replaces only the network method, so the SDK's own checks still run.
Every suite with a `requiredConfig` list checks that removing each item makes the adapter refuse to act (reject, return nothing, or keep the flag default) rather than silently succeed, which is the fail-closed rule of ADR 0021.

Vitest stays the runner, since `infrastructure/adapters` already uses it; no new dependency is added.

### Consequences

- Good, because a new vendor gets a ready-made checklist: implement the harness and the port's behaviour is verified.
- Good, because the suites catch real divergences between vendors: while they were written, they found the since-removed NextAuth adapter matching protected routes anywhere in the path, so `/blog/dashboard-tips` was sent to the login page while Better Auth let it through.
- Good, because the tests need no network or secrets and run in a few seconds.
- Bad, because a mocked SDK can drift from the real one; the suites prove the adapter honours the port given the SDK's documented behaviour, not that the vendor's API still behaves that way.
- Bad, because harnesses for SDKs that own a lot of behaviour, such as a proxy that decides redirects itself, have to model that behaviour, which is extra code to keep honest.
- Bad, because payment and analytics have no `interfaces.ts`, so their suites spell the port out themselves until those ports are made explicit.
