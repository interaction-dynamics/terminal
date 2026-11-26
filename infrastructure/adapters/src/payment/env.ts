import { createEnv } from '@t3-oss/env-nextjs';
import { z } from 'zod';

/** Optional so the app runs without Stripe; payment actions fail when it is missing. */
export const paymentEnv = () =>
  createEnv({
    server: {
      STRIPE_SECRET_KEY: z.string().optional(),
    },
    experimental__runtimeEnv: {},
    emptyStringAsUndefined: true,
  });
