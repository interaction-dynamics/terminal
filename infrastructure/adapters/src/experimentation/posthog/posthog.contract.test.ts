import { vi } from 'vitest';
import { describeExperimentationContract } from '../experimentation.contract';

const vendor = vi.hoisted(() => ({ value: false, keys: [] as string[], built: 0 }));

vi.mock('@flags-sdk/posthog', () => ({
  createPostHogAdapter: () => {
    vendor.built += 1;
    return () => ({
      decide: ({ key }: { key: string }) => {
        vendor.keys.push(key);
        return vendor.value;
      },
    });
  },
}));

describeExperimentationContract('PostHog', {
  configure: () => {
    Object.assign(vendor, { value: false, keys: [], built: 0 });
    vi.stubEnv('NEXT_PUBLIC_POSTHOG_KEY', 'phc_test');
    vi.stubEnv('NEXT_PUBLIC_POSTHOG_HOST', 'https://posthog.example.com');
  },
  load: async () => (await import('./index')).createPostHogAdapter,
  vendorDecides: (value) => {
    vendor.value = value;
  },
  evaluatedKeys: () => vendor.keys,
  vendorInitialised: () => vendor.built > 0,
  requiredConfig: [
    { name: 'NEXT_PUBLIC_POSTHOG_KEY', remove: () => vi.stubEnv('NEXT_PUBLIC_POSTHOG_KEY', '') },
    { name: 'NEXT_PUBLIC_POSTHOG_HOST', remove: () => vi.stubEnv('NEXT_PUBLIC_POSTHOG_HOST', '') },
  ],
});
