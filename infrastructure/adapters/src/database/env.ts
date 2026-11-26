import { createEnv } from '@t3-oss/env-nextjs';
import { z } from 'zod';

/**
 * Optional so the app builds and runs without a database. It is only needed once an
 * authentication provider is enabled, and the Drizzle client fails on load without it.
 */
export const databaseEnv = () =>
  createEnv({
    server: {
      DATABASE_URL: z.url().optional(),
    },
    experimental__runtimeEnv: {},
    emptyStringAsUndefined: true,
  });
