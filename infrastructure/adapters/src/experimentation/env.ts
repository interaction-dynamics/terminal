import { createEnv } from '@t3-oss/env-nextjs';
import { z } from 'zod';

/**
 * Each flag provider is opt-in. An unconfigured provider falls back to the blank adapter,
 * which returns the flag's default value.
 */
export const experimentationEnv = () =>
  createEnv({
    server: {
      STATSIG_SERVER_API_KEY: z.string().optional(),
      /** Vercel flags SDK key. */
      FLAGS: z.string().optional(),
    },
    client: {
      NEXT_PUBLIC_POSTHOG_KEY: z.string().optional(),
      NEXT_PUBLIC_POSTHOG_HOST: z.url().optional(),
    },
    // Client variables must be referenced literally so Next.js can inline them.
    experimental__runtimeEnv: {
      NEXT_PUBLIC_POSTHOG_KEY: process.env.NEXT_PUBLIC_POSTHOG_KEY,
      NEXT_PUBLIC_POSTHOG_HOST: process.env.NEXT_PUBLIC_POSTHOG_HOST,
    },
    emptyStringAsUndefined: true,
  });
