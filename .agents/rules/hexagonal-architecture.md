# Hexagonal Architecture

Apply this rule when adding any code that talks to an external system
(database, third-party API, vendor SDK, message queue, …) or when
refactoring code that currently does.

## Rule

Feature and business logic depend on **ports** (domain-typed interfaces)
and **domain entities**. External systems and vendor SDKs live behind
**adapters**. Feature code does not import a specific vendor adapter
directly; it imports from the capability folder's public boundary.

## Capability folders

The capability folder, not the vendor subfolder, is the public boundary.

For example, import and depend on `@ship-it/adapters/email`,
not on a concrete implementation such as
`@ship-it/adapters/email/resend`. All implementations inside
the same adapter folder must implement the same interface so they can be
swapped without changing feature code.

Capability folders in `infrastructure/adapters/src`
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

## Adding a non-React library

Any new non-React library (analytics, A/B testing, feature flags, error
tracking, payments, email, storage, search, queues, CMS clients,
third-party SDKs, etc.) MUST be introduced through an adapter so the
vendor can be swapped transparently:

- Place the integration in the matching capability folder, in a
  `<vendor>` subfolder, wherever that capability currently lives (see
  above). If no folder fits, create a new capability folder in
  `infrastructure/adapters/src` whose name describes the capability,
  not the vendor.
- Define or extend the capability's port (interface) so it expresses
  behaviour in domain terms, not vendor terms. Do not leak vendor types,
  options, or error shapes through the port.
- Implement the port in the vendor subfolder. Keep all imports of the
  vendor SDK confined to that subfolder.
- Feature code must depend only on the capability folder's public
  boundary, never on the concrete vendor subfolder.
- When more than one implementation can exist (e.g. multiple analytics
  providers), they must all conform to the same port so they are
  interchangeable without changes in feature code.
- Every vendor MUST pass its capability's contract suite
  (`<capability>/<capability>.contract.ts(x)`), run from
  `<capability>/<vendor>/<vendor>.contract.test.ts(x)` with the vendor
  SDK mocked, including the fail-closed checks for missing config. The
  `hexagonal-adapters` skill describes the harness; ADR 0032 explains
  why.
- React-only libraries (UI components, hooks, rendering helpers) are
  exempt from this rule.

## Enforcement

`bun run lint:boundaries` (dependency-cruiser, config in
`.config/dependency-cruiser.cjs`) checks this rule in CI and fails on:

- `apps/**` importing anything under `infrastructure/adapters/src` other
  than a capability entry point: `@ship-it/adapters/<capability>`,
  `<capability>/wrappers` (build-time Next.js config), or
  `monitoring/{client,server,telemetry}` (runtime-specific entry points
  that select the vendor themselves), or `@ship-it/adapters/env` (the
  composed env schemas, ADR 0027). There is no wiring exception:
  `apps/web/src/adapters/**` follows the same rule. If the app needs
  something only a vendor provides, add it to the capability port.
- An adapter reaching into another capability's vendor subfolder instead
  of that capability's entry point.
- `domain/entities` importing the app, the adapters or drizzle.
- A vendor SDK imported outside its vendor subfolder. The SDK → folder
  map lives in `VENDOR_SDKS` in the config: add a line there when you add
  a vendor.

`infrastructure/adapters/package.json` exports only the entry points
above, so a vendor subpath does not even resolve from another package.

## Why

So we can swap a vendor (or run two side-by-side during a migration)
without touching feature code, and so each integration has one obvious
home.
