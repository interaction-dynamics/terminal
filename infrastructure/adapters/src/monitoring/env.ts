import { createEnv } from '@t3-oss/env-nextjs';
import { z } from 'zod';

export const monitoringEnv = () =>
  createEnv({
    server: {
      /** OpenTelemetry service name. */
      TELEMETRY_PROJECT: z.string().optional(),
    },
    client: {},
    experimental__runtimeEnv: {},
    emptyStringAsUndefined: true,
  });
