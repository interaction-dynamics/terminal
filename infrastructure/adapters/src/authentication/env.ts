import { createEnv } from '@t3-oss/env-nextjs';
import { z } from 'zod';

/**
 * Authentication is opt-in: without `BETTER_AUTH_SECRET` the blank adapter is used.
 *
 * A getter rather than a constant so the value is read when a provider is chosen,
 * like the raw `process.env` reads it replaces (and so tests can stub variables).
 */
export const authenticationEnv = () =>
  createEnv({
    server: {
      /** Enables Better Auth. */
      BETTER_AUTH_SECRET: z.string().optional(),
      /** Better Auth base URL. Defaults to `https://$VERCEL_URL` on Vercel. */
      BETTER_AUTH_URL: z.url().optional(),
      /** Set by Vercel on every deployment (host name, no protocol). */
      VERCEL_URL: z.string().optional(),
    },
    experimental__runtimeEnv: {},
    emptyStringAsUndefined: true,
  });
