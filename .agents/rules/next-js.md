# Next.js Conventions

Apply this rule when writing any Next.js page, layout, Server Action,
or data-fetching code in `apps/web`.

## App Router fundamentals

- Default to **Server Components**. Add `"use client"` only when the
  component needs `useState`, `useEffect`, event handlers, or browser
  APIs.
- Use **async Server Components** for data fetching — fetch directly
  inside the component, not in a separate loader.
- Prefer `loading.tsx` and `error.tsx` in the route segment over manual
  loading state and try/catch in every component.
- Use `layout.tsx` for UI that persists across sibling routes; avoid
  re-fetching data that a parent layout already provides.

## Data fetching

- Fetch data as close to where it's consumed as possible.
- Use React's `cache()` wrapper for request-scoped deduplication of
  shared queries.
- For mutations, use **Server Actions** (`"use server"` functions) rather
  than API routes when the caller is a form or a client component in the
  same app.
- Revalidate with `revalidatePath` or `revalidateTag` after mutations;
  prefer tag-based revalidation for fine-grained control.

## Routing

- Use **route groups** (`(group)`) to share layouts without adding URL
  segments.
- Use **dynamic segments** (`[id]`) and **catch-all segments** (`[...slug]`)
  where appropriate; generate static params with `generateStaticParams`
  for known values.
- Place API route handlers in `apps/web/src/app/api/` only when an
  external client (webhook, mobile app, third-party integration) must
  call them. Prefer Server Actions for internal mutations.

## Images and assets

- Always use `next/image` for images; never raw `<img>` tags.
- Always use `next/font` for custom fonts; never load from a CDN in CSS.
- Use `next/link` for client-side navigation; never raw `<a>` tags for
  internal routes.

## Performance

- Use `Suspense` boundaries to stream in slow parts of a page
  independently.
- Prefer static rendering (`export const dynamic = 'force-static'`) for
  pages that don't need per-request data.
- Use `unstable_cache` (or `cache()` at the module level) for expensive
  computations that can be shared across requests.

## Red flags

- `"use client"` at the top of a component that has no interactivity.
- `fetch` inside `useEffect` — use a Server Component or React Query
  instead.
- Raw `<img>`, `<a>` (for internal links), or `<link rel="stylesheet">`
  in component files.
- API route handler used where a Server Action would suffice.
- Shared mutable state at the module level in a Server Component (unsafe
  across requests).

## Why

These conventions align with the Next.js App Router's mental model and
make the performance characteristics of each component explicit and
auditable at a glance.
