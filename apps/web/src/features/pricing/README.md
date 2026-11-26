---
# TODO: owner
creation_date: 2026-03-06
---

# Pricing

Shows the plans and their prices, on the landing page and on the pricing page.

## How it works

- `Pricing` renders the boilerplate's own tiers as a landing page section (`app/(main)/(landing)/page.tsx`).
- `PricingSection` renders a list of plans with a monthly/yearly switch; the `/pricing` route (`app/(main)/pricing/page.tsx`) passes it its plans.
- Both are exported from `index.ts`; the components in `components/` are private.
- `PricingSection` takes its labels from the `pricing` translation namespace (`apps/web/src/content/messages/<locale>/pricing.json`).
