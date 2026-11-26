# Enable Strict and Type-Aware oxlint Rules

## Context and Problem Statement

ADR 0006 adopted oxlint with its defaults: `.oxlintrc.json` had `"categories": {}` and `"rules": {}`.
With defaults, only part of the `correctness` category runs, and every finding is a warning, so `bun lint` exits 0 no matter what it reports.
A handful of warnings had piled up unnoticed, and AI agents (and humans) working in this repo had no lint signal they were forced to act on.
Whole classes of async bugs — floating promises, promise-returning event handlers, `any` leaking out of dynamic imports — were not checked at all, because those rules need type information.
How strict should linting be, and can type-aware rules run on this repo's TypeScript 7 setup (ADR 0012)?

## Considered Options

- Keep oxlint defaults
- Enable the `correctness`, `suspicious` and `perf` categories as warnings
- Enable the `correctness`, `suspicious` and `perf` categories as errors
- Additionally enable type-aware rules through `oxlint --type-aware` and `oxlint-tsgolint`
- Switch to typescript-eslint for type-aware rules

## Decision Outcome

Chosen option: "Enable the `correctness`, `suspicious` and `perf` categories as errors" plus "Additionally enable type-aware rules through `oxlint --type-aware` and `oxlint-tsgolint`", because errors fail CI and cannot be ignored, and type-aware rules catch the async and `any` bugs that syntax-only rules cannot see.

Warnings were rejected because a warning that does not fail CI is the same as no rule for an agent working through a task list.
typescript-eslint was rejected because it would add a second linter, slower by an order of magnitude, beside the Oxc toolchain chosen in ADR 0006.

### Type-aware linting with TypeScript 7

`oxlint-tsgolint` is built on typescript-go, the same native compiler that ships as TypeScript 7, so it does not depend on the classic Compiler API that TypeScript 7 removed.
Version `7.0.2006` was checked against this repo: it finds each package's `tsconfig.json`, builds the program (about 2,800 source files for `apps/web`), and lints the whole monorepo in about 2.5 seconds.
The root `lint` and `lint:fix` scripts now pass `--type-aware`; CI already runs `bun lint`, so `.github/workflows/validate.yml` is unchanged.
`oxlint-tsgolint` is pinned to an exact version, like `oxlint`, because rule behaviour changes between releases.

Two setup details were needed:

- The `typescript` plugin must be listed in `plugins`; a `plugins` array replaces oxlint's default set, so without it every `typescript/*` rule is silently dropped.
- TypeScript's `include` wildcards skip dot-directories, so `apps/web/src/app/.well-known/**` is not covered by any tsconfig and the `@/` path alias does not resolve there; that route imports its sibling module by relative path instead.

### Rules

All rules in `correctness`, `suspicious` and `perf` are errors.
These type-aware rules are enabled as errors: `no-floating-promises`, `no-misused-promises`, `await-thenable`, `no-unsafe-assignment`, `no-unsafe-call`, `no-unsafe-member-access`, `no-unsafe-return`, `no-unsafe-argument`, `no-unsafe-enum-comparison`, `no-unsafe-unary-minus`, `no-unnecessary-type-assertion`, `restrict-template-expressions`, `restrict-plus-operands`, `no-base-to-string`, `only-throw-error`, `prefer-promise-reject-errors`, `return-await`, `no-redundant-type-constituents`, `no-duplicate-type-constituents`, `unbound-method`, `switch-exhaustiveness-check`, `no-for-in-array`, `no-implied-eval`, `no-array-delete`, `no-meaningless-void-operator`, `no-mixed-enums` and `no-deprecated`.

Deliberate exceptions:

- `react/react-in-jsx-scope` is off: every package compiles JSX with the automatic `react-jsx` runtime, so `React` never needs to be in scope (it produced 478 false positives).
- `typescript/no-unsafe-type-assertion` (part of `suspicious`) is off: it forbids every narrowing `as`, including the only way to type a template-literal `import()`, which TypeScript types as `any`, and the partial fixtures that tests build; the `no-unsafe-*` rules above still stop `any` from flowing anywhere unchecked.
- `import/no-unassigned-import` allows CSS files, `@testing-library/jest-dom/vitest` and `@/config/env` (imported by `next.config.ts` to validate the environment at build time), which are imported for their side effects by design.
- `.agents/**` and `.config/scripts/**` turn off `no-unsafe-argument`, `no-unsafe-call` and `no-unsafe-member-access`: those Bun scripts sit outside every tsconfig, so `Bun`, `import.meta.dir` and Node built-ins have no types there.
- Stylistic type-aware rules such as `no-confusing-void-expression` and `require-await` are not enabled; the second flags every port implementation that is `async` only to satisfy its interface.

The two inline `oxlint-disable-next-line` comments (`jsx-a11y/no-autofocus` on the one-time-code field shown after the email step, `jsx-a11y/prefer-tag-over-role` on the OTP separator, which holds an icon an `<hr>` cannot) each explain why.

### Consequences

- Good, because every lint finding now fails `bun lint` and CI, so neither agents nor humans can leave one behind.
- Good, because type-aware rules found real bugs on the first run: React keys built from `item?.toString()` that collapsed to `[object Object]`, Resend errors thrown as plain objects instead of `Error`s, promise-returning `onClick`/`onSubmit` handlers, and `any` leaking out of dynamic `import()`s and `@types/mdx`.
- Good, because the whole repo still lints in a few seconds, with one tool and one config file.
- Bad, because type-aware linting needs a built TypeScript program, so `bun lint` is slower than syntax-only linting and needs dependencies installed.
- Bad, because `oxlint-tsgolint` is younger than typescript-eslint and tracks typescript-go releases, so it must be upgraded alongside TypeScript.
- Bad, because `no-deprecated` turns a dependency's new deprecation into a lint error, so a dependency bump can fail CI until the call site is migrated.
- Follow-up: once the tsconfig covers `.well-known`, the flags route can go back to the `@/` alias.
