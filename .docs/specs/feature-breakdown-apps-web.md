---
status: implemented # draft, accepted, implemented
date: 2026-11-20
---

# Feature breakdown of `apps/web/src`

## Context

`apps/web` is the Next.js App Router app of the boilerplate.
Its code is grouped by route (`app/(main)/**/_components`, `_use-cases/`, `actions.ts`) and by technical folder (`components/`, `lib/`, `config/`, a lone `feature/login-form.tsx`).
`bunx features scan apps/web/src --skip-changes` finds no feature today.

`.agents/rules/feature-layout.md` and ADR 0047 give a feature two homes: a route folder that isolates it (marked by a `feature: true` README), or `apps/web/src/features/<feature>/` when several routes, a composition page, a layout or an adapter render it.
This breakdown applies that rule to the existing code so the boilerplate demonstrates both homes.
It is a move-only refactor: no behaviour change.

## Layout

- **Route features**: the route folder stays where Next.js needs it and gains a `README.md` with `feature: true`, owner, title and a one-line description.
  Its code stays in `_components/`, `_use-cases/`, `actions.ts` and `__tests__/`.
- **`features/` features**: `apps/web/src/features/<feature>/` with an `index.ts` public API and private `components/` subfolder.
- **Not features**: composition pages and layouts (`(landing)`, `(main)/layout.tsx`, `(protected)/layout.tsx`, `dashboard`), app glue (`proxy.ts`, `instrumentation.ts`, `api/auth`, `.well-known`), the adapters in `apps/web/src/adapters/` (hexagonal architecture) and domain entities.

## Features

Migration order, top to bottom (no feature depends on another planned feature).

| #   | Feature             | Path                                                | Owner | Description                                                                                         | Depends on | Done |
| --- | ------------------- | --------------------------------------------------- | ----- | --------------------------------------------------------------------------------------------------- | ---------- | ---- |
| 1   | Login               | `apps/web/src/features/login`                       | TODO  | Lets a visitor sign in with a one-time code or a magic link sent to their email                     | —          | [x]  |
| 2   | Pricing             | `apps/web/src/features/pricing`                     | TODO  | Shows the plans and their prices on the landing page and on the pricing page                        | —          | [x]  |
| 3   | Blog                | `apps/web/src/app/(main)/blog`                      | TODO  | Lets a visitor browse the blog posts and read one                                                   | —          | [x]  |
| 4   | Notifications       | `apps/web/src/app/(main)/(protected)/notifications` | TODO  | Lets a signed-in user send a test notification through the configured provider                      | —          | [x]  |
| 5   | Email               | `apps/web/src/app/(main)/(protected)/email`         | TODO  | Lets a signed-in user send a plain and a formatted test email through the configured email provider | —          | [x]  |
| 6   | Checkout            | `apps/web/src/app/(main)/(protected)/checkout`      | TODO  | Lets a signed-in user pay for a plan and see whether the payment succeeded                          | —          | [x]  |
| 7   | User administration | `apps/web/src/app/(main)/(protected)/admin`         | TODO  | Lets an administrator list users, block or unblock them, change their role and remove them          | —          | [x]  |

### 1. Login (`features/login`)

Used by the authentication adapter wrapper (`apps/web/src/adapters/authentication/index.tsx`), not by one route, so it goes to `features/`.

Files to move:

- `apps/web/src/feature/login-form.tsx` → `apps/web/src/features/login/components/login-form.tsx`
- new `apps/web/src/features/login/index.ts`: `export { BaseLoginForm } from './components/login-form';`
- `apps/web/src/adapters/authentication/index.tsx`: import from `@/features/login`.
- The empty `apps/web/src/feature/` folder disappears.

### 2. Pricing (`features/pricing`)

Pricing is a landing section with its own purpose and also has its own route, so it goes to `features/`.
Today it is two unrelated components; both move, unchanged, under one feature:

- `apps/web/src/components/pricing-section.tsx` → `apps/web/src/features/pricing/components/pricing-section.tsx` (plans with a monthly/yearly switch, rendered by `/pricing`; only `/pricing` uses it, so it is not shared code)
- `apps/web/src/app/(main)/(landing)/_components/pricing.tsx` → `apps/web/src/features/pricing/components/pricing.tsx` (the boilerplate's own tiers, rendered by the landing page)
- new `apps/web/src/features/pricing/index.ts` exporting `Pricing`, `PricingSection` and `PricingSectionProps`.
- `app/(main)/pricing/page.tsx` and `app/(main)/(landing)/page.tsx` import from `@/features/pricing`.
  The `/pricing` page keeps its plan list and stays a thin route.
- `.agents/skills/rebrand-project/SKILL.md` points at the new path of the landing tiers.

### 3. Blog (route)

`app/(main)/blog/` (list, `[postSlug]`, layout, not-found) holds the blog and nothing else.
Add `README.md` with `feature: true`. No file moves.

### 4. Notifications (route)

`app/(main)/(protected)/notifications/` (`page.tsx`, `_components/`, `_use-cases/`). Add `README.md` with `feature: true`. No file moves.

### 5. Email (route)

`app/(main)/(protected)/email/` (`page.tsx`, `_components/`, `_use-cases/`). Add `README.md` with `feature: true`.

Files to move:

- `apps/web/src/content/emails/welcome-email.tsx` → `apps/web/src/app/(main)/(protected)/email/_components/welcome-email.tsx` (only `_use-cases/send-test-formatted-email.tsx` uses it); update that import and the path in `.agents/skills/rebrand-project/SKILL.md`.

### 6. Checkout (route)

`app/(main)/(protected)/checkout/` (`page.tsx`, `success/`, `_components/` with its tests). Add `README.md` with `feature: true`. No file moves.

### 7. User administration (route)

`app/(main)/(protected)/admin/` (`page.tsx`, `actions.ts`, `_components/`, `__tests__/`). Add `README.md` with `feature: true`.
Link the existing record `.docs/decisions/0042-manage-users-from-an-admin-panel.md` from the README. No file moves.

Each feature gets one `refactor(<feature>): …` commit.
`knip.jsonc` and `vitest.config.ts` use globs (`src/**`) that already cover the new paths; no change expected beyond the moved files.

## Shared code

Stays where it is:

- `components/section.tsx`: used by admin, checkout, email, notifications and dashboard.
- `components/typography.tsx`, `lib/format-datetime/`: used by blog, admin, translations, MDX.
- `components/language-selector.tsx`, `dark-mode-toggle.tsx`, `sitemap-footer.tsx`: rendered by the landing layout and a landing section (layout glue).
- `components/error-layout.tsx`, `theme-provider.tsx`: used by the root layouts and error pages.
- `components/ui/**`: shadcn/ui primitives, even when one feature uses them (`ui/table` in admin, `ui/input-otp` in login).
- `components/magicui/`, `ui/cover`, `ui/sparkles`, `ui/wobble-card`: presentational blocks of the landing page.
- `content/messages/**`: translation messages, loaded by namespace by the translation adapter from `config/translations.config.ts`; moving one namespace next to its feature would change the adapter.
- `content/json/faq.*`, `content/markdown/**`: page content.
- `(landing)/_components/{hero,features,differentiators}.tsx`: presentational marketing blocks used only by the landing page (allowed by the rule).
- `(protected)/protected-routes.tsx`: list of protected routes read by the authentication adapter (app glue).

Not features (pages without a capability of their own): `dashboard` (home dashboard linking to admin), `faq`, `legal`, `tutorial`, `(landing)/translations` (translation demo), `error`, `forbidden`, `unauthorized`, `login`/`logout` pages (they render the authentication adapter's `LoginForm`).

## Answers

Session 2026-11-20:

- Breakdown approved as planned; FAQ stays a content page.
- Pricing: both components move to `features/pricing`.
- Owners: not decided yet, so every README carries a `# TODO: owner` comment line.

## Open questions

- Owner of each feature (team or GitHub handle, without `@`)? Until answered, each README carries a `# TODO: owner` comment line.
- Pricing: group both pricing components under `features/pricing` (proposed), or keep the landing tiers in `(landing)/_components/` and make `/pricing` a route feature?
- FAQ: leave `faq` as a content page (proposed), or mark it as a route feature?
- The authentication adapter wrapper imports `@/app/(main)/(protected)/protected-routes`; no rule forbids it (adapters are not shared folders), so it stays. Flagged only.
