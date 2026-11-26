# Feature Layout

Apply this rule to every change that adds, moves or edits application code:
a new route, page, component, Server Action, hook, use case or test.

## Rule

**Split the code by feature, as much as possible.**
A feature is a capability a product manager would recognise (`checkout`,
`blog`, `user-admin`, `login`), not a technical layer (`components`, `hooks`,
`utils`).
Every piece of code that belongs to one feature lives in that feature's folder.

The layout follows [features-cli](https://github.com/interaction-dynamics/features)
conventions (ADR 0047), so `features scan` maps the codebase by feature, with
owners, specs and decisions, and `features check` validates it.

### Two homes for a feature

**1. A route folder, when the route isolates the feature.**
When a route segment (and its sub-routes) holds one feature and nothing else,
the route folder is the feature: add a `README.md` with `feature: true` in its
frontmatter and keep the feature's code co-located in Next.js private folders.

```
apps/web/src/app/(main)/(protected)/checkout/
├── README.md         # feature: true, owner, title, one-line description
├── page.tsx
├── success/page.tsx  # sub-route of the same feature
├── actions.ts        # Server Actions of this feature
├── _components/      # UI used only by this feature
├── _use-cases/       # queries and business logic
├── __tests__/
└── __docs__/
    ├── specs/        # NNN-title.md, created with `features new spec`
    └── decisions/    # NNN-title.md, created with `features new decision`
```

Folders starting with `_` are private in the App Router, so `_components/`,
`__tests__/` and `__docs__/` never become routes.

**2. A `features/` folder, when the feature is not tied to one route.**
Use `apps/web/src/features/<feature>/` when the feature is rendered by several
routes, inside a page that composes several features, or by a layout or an
adapter (a pricing table shown on the landing page and on `/pricing`, the
login form used by the authentication adapter).

```
apps/web/src/features/<feature>/
├── README.md         # owner, title, one-line description (no `feature: true` needed)
├── index.ts          # public entry point: what routes and other features may import
├── components/       # private: UI used only by this feature
├── use-cases/        # private: Server Actions, queries, business logic
├── __tests__/
└── __docs__/
```

### Pages that are not features

A page that assembles several features is a **composition page**, not a feature:
the landing page, a home dashboard, layouts.
Never add `feature: true` to it.
Keep it thin: it renders sections from `features/` and shared components, and
holds no business logic of its own.
Each section with its own purpose (pricing, newsletter sign-up, testimonials)
is a feature in `features/`; purely presentational marketing blocks used only
there may stay in the page's `_components/`.

### Where code goes

| The code is…                                                                    | It goes…                                                                       |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| One feature, reached through one route segment                                  | That route folder, with a `feature: true` README                               |
| One feature, used by several routes, a composition page, a layout or an adapter | `apps/web/src/features/<feature>/`                                             |
| A sub-part of a large feature with its own identity                             | `<feature folder>/features/<sub-feature>/`                                     |
| Used by two or more features                                                    | `apps/web/src/components/`, `lib/` or `config/`, moved there on the second use |
| A composition page (landing, layouts)                                           | `apps/web/src/app/`, thin, not a feature                                       |
| A shadcn/ui primitive                                                           | `apps/web/src/components/ui/`                                                  |
| A vendor integration                                                            | An adapter (see `hexagonal-architecture.md`), never a feature                  |
| A domain model                                                                  | `domain/entities` (see `domain-entities.md`), never a feature                  |

When in doubt between the two homes, start in the route folder; move the code
to `features/` (with the `extract-feature` skill) the day a second route,
a composition page or a layout needs it.

### Feature boundaries

- A route-folder feature's private folders (`_components/`, `_use-cases/`…)
  and `actions.ts` are used only inside that route segment.
  Another route never imports them: when it needs them, move the feature to `features/`.
- In `features/`, files at the root of a feature folder (`index.ts`, or
  `server.ts` for server-only exports) are its public API; its subfolders are private.
  Routes, shared code and other features import it only through that public API.
- `features/` and shared folders (`components/`, `lib/`, `config/`) never import from `app/`.
- Shared folders never import a feature. If shared code needs a feature, it is
  not shared: move it into the feature.
- A feature uses vendors through `@ship-it/adapters/<capability>` like any app code.

`bun run lint:boundaries` enforces these boundaries in CI, except imports
between two route folders, which only review catches.

### Feature README

Every feature has a `README.md` that starts with frontmatter, then a unique
`#` title, then one sentence for a product manager saying what the user can do:

```markdown
---
feature: true # only for a route folder; folders in `features/` are detected without it
owner: team-payments
---

# Checkout

Lets a signed-in user pay for a plan and see the confirmation page.
```

Never invent an owner: ask, inherit it from the parent feature, or leave a
`# TODO: owner` comment line in the frontmatter.

## Skills to use

The features-cli skills live in `.agents/skills/` (Claude Code loads them
through `.claude/skills`; other agents read the `SKILL.md` files):

| When                                                          | Skill                                                |
| ------------------------------------------------------------- | ---------------------------------------------------- |
| Starting a task, finding where something lives or who owns it | `explore-features`                                   |
| Adding a new feature, page or capability                      | `create-feature`                                     |
| Moving existing code into a feature                           | `extract-feature`, or `organize-by-feature` for many |
| Proposing how to split a folder into features                 | `plan-feature-breakdown`                             |
| Writing a feature's README, spec or decision record           | `document-feature`                                   |
| Before committing                                             | `validate-features`                                  |

Use `apps/web/src` as the skills' `PATH`.
The skills default to a `features/` folder; apply the two homes above instead
(a route folder with `feature: true` is a valid feature for features-cli).
features-cli is a root dev dependency: run `bunx features <command>` (or
`bun run check-features`), not `npx features-cli@latest`.

## Existing code outside features

The existing routes and sections were turned into features in
`.docs/specs/feature-breakdown-apps-web.md`. Code added since without a feature
README, or single-feature code left in `components/`, `lib/` or `config/`, is
still outside features. When a change touches such code:

1. Make it a feature first, in its own `refactor(<feature>): …` commit with no
   behaviour change: add the `feature: true` README to a route that isolates
   the feature, or move the code into `features/` with the `extract-feature` skill.
2. Make the change inside the feature in a separate commit.

Skip step 1 only when the user asks for a minimal change, and say so in the summary.

## Checks

- `bun run check-features` (`features check apps/web/src`): duplicate feature names, broken records.
- `bun run lint:boundaries`: imports across feature boundaries.
- Before opening a pull request, run `bunx features diff apps/web/src --since origin/master`
  and list the features and owners touched in the description.

## Red flags

- A route folder with `_components/`, `_use-cases/` or `actions.ts` but no feature README.
- `feature: true` on a composition page (landing, layouts) or on a route group that holds several features.
- A route importing another route's `_components/`, `_use-cases/` or `actions.ts`.
- Business logic, data fetching or mutations written directly in a composition page.
- Code used by a single feature added to `components/`, `lib/` or `config/`.
- An import of `@/features/<other>/components/...` or any other feature subfolder.
- A feature without a `README.md`, owner or description.
- Feature folders named after a layer (`api`, `helpers`, `hooks`) or after a vendor (`stripe`).

## Why

Agents and people ship features faster than anyone can follow.
One folder per feature keeps everything about a feature (code, tests, owner,
specs, decisions) in one place: easy to find, review, hand over and delete.
A route that already isolates a feature is that folder, so it only needs a
README; code shared across pages gets its own home in `features/`.
features-cli turns those folders into a map of the product, so the next
person or agent starts from the feature, not from a repository-wide search.
