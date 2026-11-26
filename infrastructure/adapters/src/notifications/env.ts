import { createEnv } from '@t3-oss/env-nextjs';
import { z } from 'zod';

/** Slack is opt-in; without a webhook notifications go to the blank provider. */
export const notificationsEnv = () =>
  createEnv({
    server: {
      SLACK_WEBHOOK_URL: z.url().optional(),
    },
    experimental__runtimeEnv: {},
    emptyStringAsUndefined: true,
  });
