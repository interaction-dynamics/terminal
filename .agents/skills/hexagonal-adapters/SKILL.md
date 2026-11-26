---
name: hexagonal-adapters
description: Wrap any new non-React vendor SDK (analytics, A/B testing, feature flags, payments, email, storage, search, queues, CMS, error tracking) behind a port-and-adapter boundary so the vendor can be swapped without changing feature code.
when_to_use: Adding or replacing a third-party library that talks to an external system. Triggered by imports of vendor SDKs in feature code, new entries in package.json for services, or requests like "integrate Stripe / PostHog / Resend".
user-invocable: false
---

# Hexagonal Adapters

Feature code depends on **ports** (capability folders); concrete vendor
SDKs live behind **adapters** inside those folders. React-only libraries
(UI components, hooks, rendering helpers) are exempt.

## Capability folders

The public boundary is the capability folder, not the vendor subfolder:

```
infrastructure/adapters/src/<capability>/
  index.ts                              <- port: domain-typed interface, re-exports
  <capability>.contract.ts(x)           <- contract suite every vendor must pass
  <vendor>/index.ts                     <- adapter: implements the port
  <vendor>/<vendor>.contract.test.ts(x) <- runs the contract with the SDK mocked
```

Capabilities in `infrastructure/adapters/src`
(imported as `@ship-it/adapters/<capability>`):

- `analytics`
- `authentication`
- `content-management`
- `database`
- `dev-tools`
- `email`
- `experimentation`
- `monitoring`
- `notifications`
- `payment`

`translation` stays in `apps/web/src/adapters` (imported as
`@/adapters/translation`): it has no vendor behind it and reads app-owned
config and messages. See ADR 0035.

If none fits, create a new folder in `infrastructure/adapters/src` named
after the **capability**, not the vendor (e.g. `object-storage/`, not `s3/`).

## Checklist

When adding a vendor:

1. Pick the capability folder, or create it under
   `infrastructure/adapters/src/<capability>`.
2. Define or extend the port. Express behaviour in domain terms — no
   vendor types, options, or error shapes leak through.
3. Implement the port in `<capability>/<vendor>/`. **All** imports of the
   vendor SDK stay inside that subfolder.
4. Re-export from the capability's `index.ts`.
5. Wire feature code only to the capability boundary
   (`@ship-it/adapters/<capability>`), never the vendor subfolder.
6. If more than one implementation will exist, confirm they share the
   same port so they remain interchangeable.
7. **Run the capability's contract suite against the new vendor.** Add
   `<capability>/<vendor>/<vendor>.contract.test.ts(x)` that calls
   `describe<Capability>Contract('<Vendor>', harness)` (see below). A
   vendor is not done until that run passes in
   `cd infrastructure/adapters && bun run test:ci`. If the capability has
   no contract yet, write `<capability>.contract.ts(x)` first.

## Contract tests

Each port has one shared suite, `<capability>.contract.ts(x)`, that
states its behaviour in port terms (see ADR 0032). Every vendor runs
it with a **harness** that:

- mocks the vendor SDK with `vi.mock` — no network, no secrets. When the
  SDK's constructor validates config, subclass the real client and
  replace only the network method so those checks still run (see
  `email/resend/resend.contract.test.tsx`);
- `configure()`s the env vars with `vi.stubEnv`, and `load()`s a fresh
  copy of the adapter with `await import('./index')` so env read at
  module load is picked up (the suite calls `vi.resetModules()`);
- translates domain fixtures into vendor responses, and what the SDK
  received back into domain terms;
- lists every env var the vendor cannot work without in
  `requiredConfig`. The suite removes each one and expects the adapter
  to **fail closed** — reject, return nothing, or keep the flag default
  — never silently succeed (ADR 0021).

If the suite fails for a vendor, fix the adapter, not the suite. Change
the suite only when the port itself changes, and then run it against
every vendor.

## Red flags

- A vendor SDK import (`import { ... } from "stripe"`) anywhere under
  `apps/web/src/app/` or `apps/web/src/components/`.
- A port that takes a vendor-shaped options bag.
- A new top-level folder named after a vendor.
- A new vendor subfolder without a `<vendor>.contract.test.ts(x)`.
- A contract test that reaches the network or needs a real API key.

## Why

So we can swap a vendor (or run two side-by-side during a migration)
without touching feature code, and so each integration has one obvious
home.
