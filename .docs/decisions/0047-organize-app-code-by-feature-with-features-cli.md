# Organize app code by feature with features-cli

## Context and Problem Statement

The web app groups code by route: each page keeps `_components/`, `_use-cases/` and `actions.ts` next to it, and anything else lands in technical folders (`components/`, `lib/`, a lone `feature/`).
Coding agents add features in minutes, and each one picks its own layout, so the code of one product capability ends up spread over routes and shared folders, without an owner or a record of why it was built that way.
How should the app code be organized so that agents and people keep each feature in one place, documented and owned?

## Considered Options

- Keep route co-location (`app/**/_components`, `actions.ts`) as it is, without owners or feature boundaries
- Move every feature into `apps/web/src/features/` and keep all routes thin
- Feature folders by convention only, described in the agent rules
- Feature folders following features-cli conventions (route folders with a `feature: true` README, or `apps/web/src/features/`), with its Claude skills, `features check` and dependency-cruiser boundaries

## Decision Outcome

Chosen option: "Feature folders following features-cli conventions (route folders with a `feature: true` README, or `apps/web/src/features/`), with its Claude skills, `features check` and dependency-cruiser boundaries", because it gives agents step-by-step skills for creating and moving features, a map of the codebase by feature, and checks that fail in CI when the layout drifts.

- Each feature has one folder, with a `README.md` (owner, title, one-line description) and specs and decisions in `__docs__/`.
  A route folder that isolates one feature (admin, checkout) is the feature: a `README.md` with `feature: true` marks it, and its code stays in the App Router private folders (`_components/`, `_use-cases/`) and `actions.ts`.
  A feature used by several routes, a composition page, a layout or an adapter lives in `apps/web/src/features/<feature>/`, whose root files are its public API.
  Composition pages such as the landing page and layouts are not features: they stay thin and render features and shared components.
  Code shared by several features stays in `components/`, `lib/` and `config/`.
  `.agents/rules/feature-layout.md` holds the full rule.
- The seven features-cli skills (`create-feature`, `organize-by-feature`, `explore-features`, `plan-feature-breakdown`, `extract-feature`, `document-feature`, `validate-features`) are vendored in `.agents/skills/` and linked from `.claude/skills/`, like the other project skills.
  They come from `projects/skills/skills` of interaction-dynamics/features at commit `e73edecc`, the first commit with `create-feature`, reformatted with oxfmt.
  `features skills install` is not released yet (0.15.0 does not have it); once it is, refresh them with `bunx features skills install --dir .agents/skills --force`.
- `features-cli` is a root dev dependency pinned to 0.15.0.
  Its npm package selects a platform binary through `optionalDependencies`, with no install script, so CI's `bun install --ignore-scripts` works.
- `bun run check-features` (`features check apps/web/src`) runs in the validate workflow and in the pre-push hook.
- Five dependency-cruiser rules (ADR 0026) enforce the boundaries: a feature in `features/` is reached only through the files at the root of its folder, from other features and from the rest of the app; shared folders never import a feature; route private folders are never imported from outside `app/`; and `features/` and shared folders never import from `app/`.
  Imports between two route folders are not checked, because telling route features apart needs their README, which dependency-cruiser cannot read.
- Adapters and domain entities are not features: vendors stay behind `@ship-it/adapters/<capability>` (hexagonal architecture) and models stay in `@ship-it/entities`.

Route co-location as it is was rejected because nothing records a route's owner or decisions, and nothing stops another page from reaching into its private folders.
Moving every feature into `features/` was rejected because a route that already isolates a feature (checkout and its success page, admin) would gain a thin wrapper and an extra folder for nothing, while the landing page, which assembles several features, shows the opposite case: it is not a feature at all.
A convention without tooling was rejected because agents follow a written rule unevenly, and nothing would catch a feature reaching into another feature's internals.

Existing routes become features gradually: an agent that changes such code first adds the feature README, or moves the code to `features/` with the `extract-feature` skill, in its own commit.
The skills default to a `features/` folder, so the rule tells agents to apply the two homes instead.
The features-cli MCP server (`features mcp`) and the `features.config.yaml` check rules are not released yet either, so neither is configured.

### Consequences

- Good, because each feature keeps its code, tests, owner, specs and decisions in one folder, which `features scan` and `features serve apps/web/src` turn into a map of the product.
- Good, because agents have a skill for every step (explore, create, extract, document, validate) instead of improvising a layout.
- Good, because cross-feature imports and duplicate feature names fail in CI.
- Good, because routes that isolate a feature need only a README, so the migration is small.
- Bad, because a feature has two possible homes, and agents must judge whether a route isolates it; the rule gives the test and the red flags.
- Bad, because imports between two route features are only caught in review.
- Bad, because the vendored skills can drift from the CLI version and must be refreshed by hand when `features-cli` is upgraded.
- Bad, because the skills' helper scripts need Python 3 on the machine running the agent.
