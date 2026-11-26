# Tighten the shared TypeScript configuration

## Context and Problem Statement

`config/typescript/base.json` (`@ship-it/typescript-config`) enabled only `strict: true`.
`strict` leaves several classes of bug unchecked: indexing an array or record is assumed to always hit, a function can fall off the end without returning, a `switch` case can fall through by accident, and a subclass can shadow a base method without saying so.
These are exactly the mistakes an AI agent (or a hurried human) makes most often, and the compiler is the cheapest place to catch them.

On top of that, `apps/web/tsconfig.json` did not extend the shared base at all.
It duplicated a subset of the options by hand, so any tightening of the base would have skipped the largest workspace.
`infrastructure/adapters` and `domain/entities` already extended the base.

Which extra compiler checks should every workspace share, and how do we make sure they all inherit them?

## Considered Options

- Keep `strict: true` only
- Add `noUncheckedIndexedAccess`, `noImplicitOverride`, `noImplicitReturns` and `noFallthroughCasesInSwitch`
- Add those four plus `exactOptionalPropertyTypes`
- Go further with `@tsconfig/strictest` (adds `noUnusedLocals`, `noUnusedParameters`, `noPropertyAccessFromIndexSignature`, `checkJs`, …)

## Decision Outcome

Chosen option: "Add `noUncheckedIndexedAccess`, `noImplicitOverride`, `noImplicitReturns` and `noFallthroughCasesInSwitch`", because each one catches a real class of bug, enabling them across the monorepo surfaced only a handful of errors that were all fixable with proper narrowing, and none of them conflicts with third-party types.

Each flag was evaluated on the current codebase (TypeScript 7.0.2, see ADR 0012):

- `noUncheckedIndexedAccess` — kept.
  Three errors, all real gaps: an array element read without a bounds check (`input-otp` slot lookup), a `split('.')[0]` assumed to exist, and a test reading `mock.calls[0]` without checking the mock was called.
  Each is fixed with a fallback value or an explicit guard, not a `!`.
- `noImplicitReturns` — kept.
  One error, in `findTranslation`, whose `reduce` could return `undefined`.
  It now throws (and falls back to the key, as before) when a translation is missing or resolves to a nested object, instead of casting the result `as string`.
- `noImplicitOverride` and `noFallthroughCasesInSwitch` — kept.
  No errors today; they cost nothing and guard against future regressions.
- `exactOptionalPropertyTypes` — rejected.
  It produced five errors in our code (env values passed to optional vendor options, one forwarded component prop, one stray cast), which were easy to fix.
  The blocker is the `flags` SDK: under this flag its own `AppRouterFlag` type (`origin?: string | Origin | undefined`) is no longer assignable to its own `FlagDefinitionType` (`origin?: string | Origin`), so `getProviderData(flags)` in `src/app/.well-known/vercel/flags/route.ts` fails to type-check.
  The only fixes on our side are a cast or re-wrapping every flag object, both worse than the bug class the flag guards against.
  It also adds friction to every shadcn/ui component copied in by the CLI, since forwarded optional props need `| undefined`.
  Revisit when the `flags` types are fixed upstream.
- `@tsconfig/strictest` — rejected.
  `noUnusedLocals`/`noUnusedParameters` overlap with oxlint, and `noPropertyAccessFromIndexSignature` forces bracket access on every `process.env` read for little safety gain.

`apps/web/tsconfig.json` now extends `@ship-it/typescript-config` (added as a `workspace:*` dev dependency) and keeps only the Next.js-specific overrides (`target`, `lib`, `allowJs`, `noEmit`, `jsx`, `incremental`, the `next` plugin, `paths`, `types`).
`apps/web/tsconfig.tsbuildinfo` is already ignored by the root `.gitignore` (`*.tsbuildinfo`).

### Consequences

- Good, because every workspace now inherits one set of compiler checks from a single file, so future tightening is a one-line change.
- Good, because unchecked array/record lookups and missing returns are caught at compile time instead of failing at runtime.
- Good, because agents get immediate, precise compiler feedback for the most common classes of mistake.
- Bad, because indexed reads now need a guard or a fallback even where the author "knows" the index exists, and shadcn/ui components copied in by the CLI may need the same small fix.
- Bad, because optional properties can still receive an explicit `undefined` until `exactOptionalPropertyTypes` can be enabled.
