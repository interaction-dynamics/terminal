# Upgrade to TypeScript 7

## Context and Problem Statement

TypeScript 7.0 (GA 2026-07-08) is a full rewrite of the compiler in Go
("tsgo"), delivering roughly 8-12x faster type-checking and builds.
`typescript` was pinned at `5.9.2` in `apps/web`.
Moving to the latest release is desirable for the speed gain, but TS 7.0
no longer ships the classic JavaScript Compiler API (`lib/typescript.js`)
that tooling has relied on for years.
Next.js (`16.1.6`, used by this app) reads that API directly, both to
parse `tsconfig.json` when loading `next.config.ts` and to run its own
build-time type-checking.
With `typescript@7.0.2` alone, `next dev` and `next build` fail outright:
`next.config.ts` cannot be transpiled, and the TypeScript build step
reports the package as unusable.

## Considered Options

- Stay on TypeScript 5.9.2 until the ecosystem catches up
- Upgrade `typescript` to 6.0.3 (latest version that still ships the
  classic API) and stop there
- Dual-package: keep `typescript` on 6.0.3 for tooling, add
  `@typescript/native-preview` (tsgo) as a separate fast type-checker
- Upgrade `typescript` to 7.0.2 and also move to Next.js `16.3.0-preview`,
  which adds an explicit `experimental.useTypeScriptCli` opt-in that
  makes Next call the native `tsc` binary instead of the removed
  Compiler API

## Decision Outcome

Chosen option: "Upgrade `typescript` to 7.0.2 and Next.js to
`16.3.0-preview.7`", because it is the only option that gets the actual
TS7 engine into the primary `typescript` dependency (rather than bolting
on a second, separate type-checking tool) while keeping `next dev` and
`next build` working. Verified locally: `next build` compiles, type-checks
(`Finished TypeScript in 3.6s`) and only fails afterwards on a missing
`FLAGS` secret that is unrelated to this change and expected in an
environment without production secrets configured.

Two follow-on fixes were required to make this combination work:

- `infrastructure/adapters` also depended on `next@16.1.6` directly; it
  was bumped alongside `apps/web` to avoid two physical `next` installs
  with mismatched types (`NextRequest` from one instance is not
  assignable to `NextRequest` from another).
- Several packages (`flags`, `@vercel/edge-config`, and transitively
  `@opentelemetry/api`) pinned peer ranges that don't match a
  prerelease version under strict semver, which caused `bun` to install
  a second, duplicate copy of `next` to satisfy them. Root-level
  `overrides` for `next` and `@opentelemetry/api` collapse the whole
  workspace onto one physical copy of each.
- `next.config.ts` sets `experimental.useTypeScriptCli: true` so Next
  invokes the native `tsc` binary directly instead of the removed
  Compiler API.
- Payload's generated `studio-2/layout.tsx` does a side-effect import of
  `@payloadcms/next/css` (a CSS-only export with no `.d.ts`). TypeScript
  7 flags this (previously silent); an ambient declaration was added at
  `apps/web/src/types/payload-css.d.ts` rather than editing the
  generated file.

### Consequences

- Good, because type-checking and builds get the ~8-12x speedup of the
  native Go compiler.
- Good, because `typescript` itself — not a bolted-on side tool — is the
  package used everywhere, so editors and CI see the same engine.
- Bad, because the app now depends on a Next.js **preview** release
  (`16.3.0-preview.7`), which is pre-GA and carries more upgrade risk
  than a stable minor.
- Bad, because tools built on the classic Compiler API (`ts-morph`,
  custom AST transformers, `ts-patch`) will not work in this repo until
  they add tsgo support.
- Bad, because the `next`/`@opentelemetry/api` version overrides in the
  root `package.json` need to be revisited (and likely can be dropped)
  once the ecosystem's peer ranges are updated to accept TS7-era Next.js
  prereleases.
- Follow-up: move off the Next.js preview channel to a stable `16.3.x`
  release once one ships, and re-check whether the `overrides` are still
  needed.
