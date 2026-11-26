import {
  createPostHogAdapter,
  createStatsigAdapter,
  createVercelAdapter,
} from '@ship-it/adapters/experimentation';
import { flag } from 'flags/next';

export const hideLogoLocal = flag({
  key: 'hide-logo-local',
  defaultValue: false,
  decide() {
    return false;
  },
});

export const hideLogoVercel = flag({
  key: 'hide-logo-vercel',
  defaultValue: false,
  adapter: createVercelAdapter(false),
});

export const hideLogoPostHog = flag({
  key: 'hide-logo-posthog',
  defaultValue: false,
  adapter: createPostHogAdapter(false),
});

export const hideLogoStatsig = flag({
  key: 'hide-logo-statsig',
  defaultValue: false,
  adapter: createStatsigAdapter(false),
});
