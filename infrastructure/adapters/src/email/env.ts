import { createEnv } from '@t3-oss/env-nextjs';
import { z } from 'zod';

/**
 * Each vendor is opt-in through its API key. Resend takes priority over Mailgun when both
 * are set (ADR 0021); with neither, emails are dropped by the blank provider.
 *
 * A getter rather than a constant so the provider is chosen from the current environment,
 * like the raw `process.env` reads it replaces (and so tests can stub variables).
 */
export const emailEnv = () =>
  createEnv({
    server: {
      RESEND_API_KEY: z.string().optional(),
      /** Default sender for Resend, e.g. `App <hello@example.com>`. */
      RESEND_EMAIL_FROM: z.string().optional(),
      MAILGUN_API_KEY: z.string().optional(),
      /** Required to send with Mailgun. */
      MAILGUN_DOMAIN: z.string().optional(),
      /** Default sender for Mailgun. Falls back to `postmaster@$MAILGUN_DOMAIN`. */
      MAILGUN_EMAIL_FROM: z.string().optional(),
    },
    experimental__runtimeEnv: {},
    emptyStringAsUndefined: true,
  });
