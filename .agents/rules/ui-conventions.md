# UI Conventions

Apply this rule when making any user-facing UI change.

## Rule

For visual design (palette, typography, layout, copy, motion, imagery),
follow the `design-taste-frontend` skill (tasteskill,
`.agents/skills/design-taste-frontend/SKILL.md`, ADR 0050) on any UI work:
run its deal, build to its system, and pass its checker and finish gate
before handing the page over. The implementation rules below still apply
to what it produces:

- Put the palette and type tokens the skill deals into
  `apps/web/src/app/(main)/globals.css` as theme tokens, and load its
  fonts with `next/font`, not Google Fonts `<link>` tags.
- In `apps/web`, build inside the existing Next.js app (never switch it
  to `output: 'export'`) and point the checker and gate at the running
  app (`--start http://localhost:3000/<route>`).

For UI implementation:

- Reuse shadcn/ui components from `apps/web/src/components/ui`.
- Use theme tokens from `apps/web/src/app/(main)/globals.css`. Do not
  hard-code colors or spacing values that already exist as tokens.
- Keep effects and motion to what the skill deals for the page kind;
  no decoration beyond it.
- Use `lucide-react` icons for common controls.
- Server Components are the default; reach for `"use client"` only when
  the component needs state, effects, or browser-only APIs.
- Use `next/image` for all images — never raw `<img>` tags.

## Accessibility

- Every interactive element must be keyboard-accessible.
- Images need descriptive `alt` text (or `alt=""` for decorative ones).
- Use semantic HTML elements (`<button>`, `<nav>`, `<main>`, `<section>`)
  rather than `<div>` click handlers.
- Playwright accessibility tests live in `apps/web/e2e/` — run them
  after any significant UI change.

## Red flags

- Hex colors or arbitrary Tailwind values where a token exists.
- New UI primitives written from scratch when a shadcn equivalent
  exists.
- `"use client"` at the top of a component that has no interactivity.
- Raw `<img>` tags instead of `next/image`.
- `<div onClick>` where a `<button>` belongs.

## Why

Consistency lets us iterate on the visual system in one place. Using
tokens and shared primitives means a theme tweak is a one-line change,
not a sweep across dozens of files.
