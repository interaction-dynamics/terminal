# Add an environment variable

Environment variables are declared in typed schemas and never read from `process.env` directly.
See [ADR 0027](../decisions/0027-validate-environment-variables-with-t3-env.md) for why.

## Where the schema lives

- A variable used by an adapter belongs to its capability: `infrastructure/adapters/src/<capability>/env.ts`.
- A variable used only by the app belongs in `apps/web/src/config/env.ts`.

`apps/web/src/config/env.ts` composes every capability schema, and `next.config.ts` imports it, so the whole environment is validated when the app builds or starts.

## Steps

1. Add the variable to the right schema.
   Put it under `server`, or under `client` if the browser needs it, which requires the `NEXT_PUBLIC_` prefix.
   Use `shared` only for variables both sides read that are not prefixed, such as `NODE_ENV`.
2. Make it `.optional()` if it configures a vendor.
   An unset vendor variable must fall back to the blank adapter, not fail the build ([ADR 0021](../decisions/0021-fail-closed-authentication-and-complete-email-providers.md)).
   Validate the format of set values (`z.url()`, `.regex()`) where it matters.
3. For a `client` or `shared` variable, also add it to `experimental__runtimeEnv` as a literal `process.env.NEXT_PUBLIC_…` read, so Next.js can inline it into the browser bundle.
   Server variables need no entry there.
4. For a new capability schema, re-export its getter from `infrastructure/adapters/src/env.ts` and add it to `extends` in `apps/web/src/config/env.ts`.
5. Read it through the schema:
   - in an adapter, `emailEnv().RESEND_API_KEY`;
   - in the app, `import { env } from '@/config/env'` and `env.RESEND_API_KEY`.
6. Document it in `apps/web/.env.local.example`, with an empty value and a comment if its default or effect is not obvious.

## Example

```ts
// infrastructure/adapters/src/notifications/env.ts
export const notificationsEnv = () =>
  createEnv({
    server: {
      SLACK_WEBHOOK_URL: z.url().optional(),
    },
    experimental__runtimeEnv: {},
    emptyStringAsUndefined: true,
  });
```

```ts
// infrastructure/adapters/src/notifications/index.ts
if (notificationsEnv().SLACK_WEBHOOK_URL) return await import('./slack');
```
