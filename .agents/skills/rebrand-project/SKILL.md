---
name: rebrand-project
description: Rebrand a project created from the Ship it boilerplate — replace every "Ship it" / ship-it variant with the new product's name, description, repository and contact details, then sweep the whole repo until nothing is left unexplained.
when_to_use: Starting a new product from this boilerplate, or renaming a project that still says "Ship it" anywhere. Triggered by requests like "rebrand this to X", "rename the project", "replace Ship it with X", or a new project whose `project.json` still has `"title": "Ship it"`.
user-invocable: true
---

# Rebrand a Project

A project cloned from Ship it carries the boilerplate's name in config,
UI copy, emails, tests, telemetry keys and docs. Rebranding means
**checking everywhere**: start from the known locations below, but the
repo-wide sweep is the source of truth — the list goes stale, the grep
does not.

## 1. Collect the new identity

Ask the user for anything you cannot derive, and confirm the derived
forms before editing:

| Form                | Example                                                      | Used for                                  |
| ------------------- | ------------------------------------------------------------ | ----------------------------------------- |
| Display name        | `Life Productivity`                                          | UI, page titles, emails, docs headings    |
| Kebab slug          | `life-productivity`                                          | `package.json` names, service names, keys |
| Other casings       | `life_productivity`, `LIFE_PRODUCTIVITY`, `LifeProductivity` | only where the old name used that casing  |
| Repository URL      | `https://github.com/<owner>/life-productivity`               | `repository.ts`, `apps/web/package.json`  |
| Product description | one sentence                                                 | `project.json` `description`, metadata    |
| Contact email       | `hello@life-productivity.app`                                | `project.json` socials, `mailto:` links   |
| Company (optional)  | `Interaction Dynamics`                                       | `project.json` `company`, footer          |

Also ask whether to rename the `@ship-it/*` workspace scope (step 4).
Default: keep it.

## 2. Sweep the whole repo

Run every search from the repository root and keep the output — it is
your checklist.

```bash
# Every case and separator variant: Ship it, Ship It, ship-it, ship_it,
# SHIP_IT, ShipIt, shipit, ship.it, `ship-it.` symbol keys, @ship-it/ scopes
git grep -niE 'ship[- _.]?it' -- ':!bun.lock'

# Same, without the workspace scope, to see the real branding hits
git grep -niE 'ship[- _.]?it' -- ':!bun.lock' | grep -v '@ship-it/'

# Boilerplate-specific copy and contacts that are not the name itself
git grep -niE 'shipping|interaction[- ]dynamics|example\.com' -- ':!bun.lock'

# File and folder names
git ls-files | grep -iE 'ship[- _.]?it'

# Untracked local files grep skipped (env files, local config)
grep -rniE 'ship[- _.]?it' apps/web/.env* .env* 2>/dev/null
```

Then list the **binary and visual assets** grep cannot read. Do not edit
them; give the user the list to replace by hand:

```bash
git ls-files | grep -iE '(favicon|logo|icon|apple-icon|opengraph-image|twitter-image|manifest)\.|\.(ico|png|jpe?g|webp|svg|gif)$' \
  | grep -vE '^\.claude/skills/'
```

Look at least at `apps/web/src/app/favicon.ico`, any `icon.*`,
`apple-icon.*`, `opengraph-image.*`, `twitter-image.*` or
`manifest.*` under `apps/web/src/app`, and everything in
`apps/web/public/`. Also mention the landing logo (a lucide `Terminal`
icon in `apps/web/src/app/(main)/(landing)/layout.tsx`).

## 3. Change the known locations

These are the places found when Life Productivity was rebranded from
this boilerplate. Edit each one, then go back to the sweep output for
anything not listed here.

**Product identity — single source of truth**

- `project.json`: `title` (display name), `description`, `company`,
  `socials.email` and any `socials` links still pointing at
  `example.com`. `getProductName()`, `getProductDescription()` and
  `getCompanyName()` in `apps/web/src/config/project.ts` read it; the
  root metadata title, the landing header, the login and logout pages,
  the welcome email and the test notification all use them.
- If you find the name written into UI or copy instead of read from
  `getProductName()`, switch it to `getProductName()` rather than
  replacing the string, so the next rename is a one-line change.

**Repository and package names**

- `apps/web/src/config/repository.ts` — `getRepositoryUrl()` (landing
  header, hero, pricing).
- `apps/web/package.json` — `repository.url`.
- Root `package.json` — `name` (kebab slug).
- `README.md` — title and intro.

**Copy and emails**

- `infrastructure/adapters/src/authentication/better-auth/emails/otp-email.tsx`
  — OTP email subjects (adapters cannot import the app config, so the
  name is written in).
- `apps/web/src/app/(main)/(protected)/email/_components/welcome-email.tsx` — the body still
  says "Start shipping your next project today", a Ship it pun. Rewrite
  it for the new product.
- `apps/web/src/features/pricing/components/pricing.tsx` — the
  `mailto:ship-it@…` link.
- The landing page copy (`(landing)/_components/hero.tsx`, the pricing feature, FAQ)
  and the i18n messages in `apps/web/src/content/messages/<locale>/*.json`
  for every locale: they describe the boilerplate, not the product.

**Keys, service names and telemetry**

- `infrastructure/adapters/src/monitoring/monitoring.contract.ts` —
  telemetry service name `ship-it-web`.
- Any `Symbol.for('ship-it.…')` key (for example
  `Symbol.for('ship-it.mcp-tool-error')` in
  `infrastructure/adapters/src/mcp/tool.ts`, when that adapter exists).

**Tests that assert the name**

- `apps/web/e2e/example.test.ts` reads `project.json`, so it follows
  automatically; check any other e2e test the sweep finds.
- `apps/web/src/adapters/translation/i18n/_private/findTranslation.test.tsx`
  uses "Ship It" as sample data; replace it so the sweep stays clean.

**Agent docs**

- `AGENTS.md` — title and intro line.
- `.docs/architecture/overview.md` — intro sentence and the root of the
  monorepo tree (`ship-it/`).

## 4. Workspace scope `@ship-it/*` (optional — ask first)

Renaming the scope is mechanical but wide: about 50 files. Only do it if
the user says yes. It touches:

- every import of `@ship-it/adapters`, `@ship-it/entities`,
  `@ship-it/typescript-config` in `apps/`, `domain/`, `infrastructure/`;
- every workspace `package.json` (`name` and `workspace:*`
  dependencies) and every `tsconfig.json` `extends`;
- the root `package.json` scripts (`turbo dev --filter=@ship-it/web`)
  and any other turbo `--filter`;
- `.config/dependency-cruiser.cjs` (messages and path regexes);
- `AGENTS.md`, `.agents/rules/hexagonal-architecture.md`,
  `.agents/skills/hexagonal-adapters/SKILL.md`,
  `.docs/architecture/overview.md` and the decision records in
  `.docs/decisions/` that quote `@ship-it/adapters/<capability>`.

Replace `@ship-it/` with `@<slug>/` across tracked files, then
regenerate `bun.lock` with `bun install` — never edit the lockfile by
hand.

## 5. Keep the boilerplate link

Pulling boilerplate updates must keep working:

- Keep the `git remote add boilerplate git@github.com:interaction-dynamics/ship-it.git`
  and `git pull boilerplate master --rebase` instructions in
  `README.md`.
- Keep (or add) a short "Built on [Ship it](https://github.com/interaction-dynamics/ship-it)"
  credit in `README.md`.

These are the expected remaining matches.

## 6. Verify

```bash
bun install
bun run format:fix
bun run lint
bun run check-types
bun run test:ci
```

Then run the sweep from step 2 again. Explain every remaining match to
the user, one line each — expected leftovers are the boilerplate remote
and credit in `README.md` and, if the scope was kept, `@ship-it/`
imports. Anything else is a miss: fix it and sweep again.

Finally, remind the user of what lives outside the repo: the GitHub
repository name, the Vercel project, database names,
OAuth app names and sender domains configured in env files or vendor
dashboards.

## Red flags

- Replacing only the strings from step 3 without running the sweep.
- A blanket `sed` over the repo that also rewrites the boilerplate
  remote URL or `bun.lock`.
- Writing the new name into a component instead of using
  `getProductName()`.
- Renaming the `@ship-it/*` scope without asking, or without
  regenerating `bun.lock`.
- Skipping a casing: `ShipIt`, `SHIP_IT`, `ship_it` hide in env names,
  symbols and constants.
- Editing images or icons yourself instead of listing them for the user.

## Why

A missed "Ship it" shows up in production — an email subject, a page
title, a telemetry service name — long after the rename. The sweep
catches what a fixed list cannot, and routing the display name through
`project.json` keeps the next rename small.
