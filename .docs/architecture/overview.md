# Architecture Overview

This document describes the high-level architecture of the ship-it boilerplate:
how the repository is structured, how business logic is isolated from external
vendors, and how the design system is organised.

---

## Monorepo layout

The repository is a Bun workspace.
Top-level directories map directly to concerns:

```
ship-it/
├── apps/web/           # Next.js web application
├── config/typescript/  # Shared TypeScript configuration
├── domain/entities/    # Domain models (shared across apps)
├── infrastructure/     # Vendor adapters, including the database (Drizzle / PostgreSQL)
└── .docs/              # Architecture notes and decision records
```

Turborepo orchestrates tasks (`build`, `test`, `lint`) with dependency-aware
caching so only changed packages are rebuilt.
Adding a second app (mobile, Rust service, …) is a first-class operation: add a
workspace entry and wire it into the Turborepo pipeline.

See [ADR 0007](../decisions/0007-use-monorepo-architecture.md) for the rationale
behind this structure.

---

## Hexagonal architecture

The central design principle is **hexagonal architecture** (ports and adapters).
Business logic depends on abstract ports; concrete vendor implementations live
behind adapters that can be swapped without touching feature code.

```
┌──────────────────────────────────────────────────────┐
│  Feature / page code                                 │
│  depends on capability folder (public boundary)      │
└────────────────────┬─────────────────────────────────┘
                     │ imports from
                     ▼
┌──────────────────────────────────────────────────────┐
│  Capability folder                                   │
│  (e.g. infrastructure/adapters/src/email)            │
│  ├── interfaces.ts   ← port definition (domain types)│
│  └── index.ts        ← re-exports the active impl.   │
└────────────────────┬─────────────────────────────────┘
                     │ delegates to
                     ▼
┌──────────────────────────────────────────────────────┐
│  Vendor subfolder  (e.g. .../email/resend/)          │
│  Imports from the vendor SDK; implements the port.   │
│  Never imported directly by feature code.            │
└──────────────────────────────────────────────────────┘
```

### Capability folders

Each folder represents a **capability**, not a vendor.
Adapters live in `infrastructure/adapters/src/` (the `@ship-it/adapters` package)
(see ADR 0013, ADR 0023 and ADR 0035).
`translation` is the one exception: it has no vendor behind it and reads app-owned config and messages, so it stays in the app:

| Capability           | Typical responsibility                | Location                  |
| -------------------- | ------------------------------------- | ------------------------- |
| `analytics`          | Page-view and event tracking          | `infrastructure/adapters` |
| `authentication`     | Sign-in, session management           | `infrastructure/adapters` |
| `content-management` | Fetching and rendering CMS content    | `infrastructure/adapters` |
| `database`           | Drizzle schema and client             | `infrastructure/adapters` |
| `dev-tools`          | Development-only helpers              | `infrastructure/adapters` |
| `email`              | Transactional email delivery          | `infrastructure/adapters` |
| `experimentation`    | A/B tests and feature flags           | `infrastructure/adapters` |
| `monitoring`         | Error logging and performance tracing | `infrastructure/adapters` |
| `notifications`      | Push and in-app notifications         | `infrastructure/adapters` |
| `payment`            | Checkout and subscription management  | `infrastructure/adapters` |
| `translation`        | i18n message loading and formatting   | `apps/web/src/adapters`   |

`apps/web/src/adapters/` also has `authentication` and `experimentation` folders.
`authentication` is a thin wrapper over `@ship-it/adapters/authentication` that binds app-specific config (`protectedRoutes`, `BaseLoginForm`).
`experimentation` holds a React `ExperimentationProvider`, separate from the flag adapters.
A capability that needs no app-specific config, such as `email`, has no wrapper: import it from `@ship-it/adapters/<capability>` directly (see ADR 0037).

A new capability goes in `infrastructure/adapters/src/`.
A new vendor goes next to the other vendors of its capability, so they keep sharing one port.

### Rules

- Feature code imports from the capability folder only (`@ship-it/adapters/<capability>`
  or `@/adapters/<capability>`), never from a vendor subfolder such as
  `.../email/resend`.
- The port (`interfaces.ts`) expresses behaviour in **domain terms**.
  Vendor-specific types must not leak through it.
- All implementations inside the same capability folder must satisfy the same
  port so they are interchangeable.
- React-only libraries (UI components, hooks, rendering helpers) are exempt
  from this rule.
- `bun run lint:boundaries` (dependency-cruiser) enforces these rules in CI;
  see [ADR 0026](../decisions/0026-enforce-import-boundaries-with-dependency-cruiser.md).

---

## Domain entities

Entities are the source of truth.
They live in `domain/entities/src/` (the `@ship-it/entities` package) as plain TypeScript types validated with
**Zod** — no ORM imports, no framework dependencies:

```ts
// domain/entities/src/post.ts
export const Post = z.object({
  title: z.string(),
  slug: z.string(),
  // …
});

export type Post = z.infer<typeof Post>;
```

The database schema in `infrastructure/adapters/src/database/drizzle/schema.ts`
mirrors the entity; the entity is never derived from the schema.
When a field changes, update the entity first, then the schema, then regenerate
the migration with `bun run db:generate`.

---

## Next.js application structure

The web application follows Next.js App Router conventions.

```
apps/web/src/
├── app/(main)/          # Route segments; a segment that isolates a feature is one (README `feature: true`)
│   ├── blog/
│   ├── pricing/
│   └── …
├── features/            # Features used by several routes, composition pages, layouts or adapters
├── adapters/            # `translation`, `authentication` wrapper, `experimentation` (see above)
├── components/          # UI shared by several features
│   └── ui/              # shadcn/ui primitives
├── lib/                 # Utilities and helpers shared by several features
└── config/              # App-wide constants and configuration
```

### Feature folders

Code is split by feature as much as possible (see
[ADR 0047](../decisions/0047-organize-app-code-by-feature-with-features-cli.md)
and `.agents/rules/feature-layout.md`).
Each feature owns one folder, with a `README.md` (owner, title and one-line
description, read by features-cli) and its specs and decisions in `__docs__/`.
A feature has one of two homes:

| Home                                       | When                                                                         | Layout                                                                                     |
| ------------------------------------------ | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Route folder with a `feature: true` README | The route segment (and its sub-routes) isolates the feature: admin, checkout | `page.tsx`, `actions.ts`, private `_components/`, `_use-cases/`, `__tests__/`, `__docs__/` |
| `apps/web/src/features/<feature>/`         | Several routes, a composition page, a layout or an adapter use the feature   | `index.ts` (public API), private `components/`, `use-cases/`, `__tests__/`, `__docs__/`    |

Composition pages that assemble several features, such as the landing page and
layouts, are not features: they stay thin and render features and shared components.
Code shared by several features lives in `components/`, `lib/`, or `config/`, which
never import a feature or a route.
`bun run lint:boundaries` enforces these boundaries and `bun run check-features`
validates the features.
`bunx features serve apps/web/src` shows the features, owners, specs and decisions in a
local dashboard.

The boilerplate demonstrates both homes: `blog`, `checkout`, `email`,
`notifications` and `admin` are route features, while `login` (rendered by the
authentication adapter wrapper) and `pricing` (a landing section with its own
route) live in `features/`.
`.docs/specs/feature-breakdown-apps-web.md` records the breakdown.

### Server vs. client components

Server Components are the default.
A component receives `"use client"` only when it needs `useState`, `useEffect`,
event handlers, or browser-only APIs.
Mutations use Server Actions; API routes (`app/api/`) are reserved for external
callers such as webhooks or mobile apps.

---

## Design system

The UI is built on three layers:

1. **Tailwind CSS** — utility classes driven by design tokens defined in
   `apps/web/src/app/(main)/globals.css` (CSS custom properties).
   Hard-coded hex values or arbitrary spacing values that duplicate a token are
   a red flag.

2. **shadcn/ui** — accessible, unstyled primitives in
   `apps/web/src/components/ui/`.
   New UI elements should reuse or extend these before reaching for a
   hand-rolled component.

3. **lucide-react** — icon set used for all common controls.

### Accessibility requirements

- Every interactive element must be keyboard-accessible.
- Images need descriptive `alt` text (`alt=""` for decorative images).
- Use semantic HTML elements (`<button>`, `<nav>`, `<main>`, `<section>`)
  instead of `<div onClick>` handlers.

---

## Decision records

Non-trivial technical choices are recorded as
[MADR](https://adr.github.io/madr/) files in `.docs/decisions/`.
Architecture and design notes live in `.docs/architecture/`.
Operational guidance lives in `.docs/how-to/`.

When a choice is made (library, vendor, pattern, protocol), write the record
before or alongside the implementation — not after the fact.

## Feature specs

What each feature must do, and why, is recorded as a
[GitHub Spec Kit](https://github.com/github/spec-kit) spec in
`specs/NNN-<feature-name>/spec.md`, written from the prompt or client
document before the code and kept up to date as the feature changes.
See `.agents/rules/feature-specs.md` and
[ADR 0045](../decisions/0045-store-prompt-specs-in-spec-kit-format.md).
