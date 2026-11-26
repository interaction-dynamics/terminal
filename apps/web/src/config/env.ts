import { createEnv } from '@t3-oss/env-nextjs';
import {
  analyticsEnv,
  authenticationEnv,
  databaseEnv,
  emailEnv,
  experimentationEnv,
  monitoringEnv,
  notificationsEnv,
  paymentEnv,
} from '@ship-it/adapters/env';
import { z } from 'zod';

/**
 * The app's validated environment. Each capability in `@ship-it/adapters` owns the schema
 * for its own variables; this file composes them and adds the variables the app owns.
 *
 * Importing it from `next.config.ts` validates the whole environment at build and start time.
 * Every vendor variable is optional, so the app still builds and runs with nothing set and an
 * unconfigured vendor falls back to its blank adapter (ADR 0021, ADR 0027).
 *
 * Read variables from here, never from `process.env`. See `.docs/how-to/add-an-environment-variable.md`.
 */
export const env = createEnv({
  extends: [
    analyticsEnv(),
    authenticationEnv(),
    databaseEnv(),
    emailEnv(),
    experimentationEnv(),
    monitoringEnv(),
    notificationsEnv(),
    paymentEnv(),
  ],
  shared: {
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  },
  experimental__runtimeEnv: {
    NODE_ENV: process.env.NODE_ENV,
  },
  emptyStringAsUndefined: true,
});
