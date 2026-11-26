import { createEnv } from '@t3-oss/env-nextjs';
import { z } from 'zod';

/** Each analytics script is opt-in and only loads in production. */
export const analyticsEnv = () =>
  createEnv({
    shared: {
      NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    },
    client: {
      NEXT_PUBLIC_CONTENTSQUARE_ID: z.string().optional(),
      /** Numeric site id; it is interpolated into an inline script. */
      NEXT_PUBLIC_HOTJAR_ID: z
        .string()
        .regex(/^\d+$/, 'Must be the numeric Hotjar site id')
        .optional(),
      NEXT_PUBLIC_GOOGLE_ANALYTICS_ID: z.string().optional(),
    },
    // Client and shared variables must be referenced literally so Next.js can inline them.
    experimental__runtimeEnv: {
      NODE_ENV: process.env.NODE_ENV,
      NEXT_PUBLIC_CONTENTSQUARE_ID: process.env.NEXT_PUBLIC_CONTENTSQUARE_ID,
      NEXT_PUBLIC_HOTJAR_ID: process.env.NEXT_PUBLIC_HOTJAR_ID,
      NEXT_PUBLIC_GOOGLE_ANALYTICS_ID: process.env.NEXT_PUBLIC_GOOGLE_ANALYTICS_ID,
    },
    emptyStringAsUndefined: true,
  });
