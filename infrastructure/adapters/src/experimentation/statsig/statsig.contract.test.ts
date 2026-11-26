import { vi } from 'vitest';
import { describeExperimentationContract } from '../experimentation.contract';

type Gate = { name: string; value: boolean };

const vendor = vi.hoisted(() => ({ value: false, keys: [] as string[], built: 0 }));

vi.mock('@flags-sdk/statsig', () => ({
  statsigAdapter: {
    featureGate: (toValue: (gate: Gate) => boolean) => {
      vendor.built += 1;
      return {
        decide: async ({ key }: { key: string }) => {
          vendor.keys.push(key);
          return toValue({ name: key, value: vendor.value });
        },
      };
    },
  },
}));

describeExperimentationContract('Statsig', {
  configure: () => {
    Object.assign(vendor, { value: false, keys: [], built: 0 });
    vi.stubEnv('STATSIG_SERVER_API_KEY', 'secret-test');
  },
  load: async () => (await import('./index')).createStatsigAdapter,
  vendorDecides: (value) => {
    vendor.value = value;
  },
  evaluatedKeys: () => vendor.keys,
  vendorInitialised: () => vendor.built > 0,
  requiredConfig: [
    { name: 'STATSIG_SERVER_API_KEY', remove: () => vi.stubEnv('STATSIG_SERVER_API_KEY', '') },
  ],
});
