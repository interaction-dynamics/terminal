import { createPostHogAdapter as createPostHogFlagsAdapter } from '@flags-sdk/posthog';
import { createBlankAdapter } from '../blank';
import type { BooleanFlagAdapter } from '../interfaces';
import { experimentationEnv } from '../env';

/**
 * PostHog builds its client as soon as an adapter is created, so the provider
 * is only used once configured.
 *
 * The SDK's default adapter reads `POSTHOG_PROJECT_API_KEY`/`POSTHOG_HOST`; the
 * client is built explicitly so the app keeps a single set of PostHog variables.
 */
export const createPostHogAdapter = (fallback = false): BooleanFlagAdapter => {
  const { NEXT_PUBLIC_POSTHOG_KEY: key, NEXT_PUBLIC_POSTHOG_HOST: host } = experimentationEnv();

  return key && host
    ? createPostHogFlagsAdapter({ postHogKey: key, postHogOptions: { host } })<boolean>()
    : createBlankAdapter(fallback);
};
