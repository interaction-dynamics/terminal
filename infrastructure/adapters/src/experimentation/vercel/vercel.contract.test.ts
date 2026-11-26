import { vi } from 'vitest';
import { describeExperimentationContract } from '../experimentation.contract';

const vendor = vi.hoisted(() => ({ value: false, keys: [] as string[], built: 0 }));

vi.mock('@flags-sdk/vercel', () => ({
  vercelAdapter: () => {
    vendor.built += 1;
    return {
      decide: ({ key }: { key: string }) => {
        vendor.keys.push(key);
        return vendor.value;
      },
    };
  },
}));

describeExperimentationContract('Vercel Flags', {
  configure: () => {
    Object.assign(vendor, { value: false, keys: [], built: 0 });
    vi.stubEnv('FLAGS', 'vf_test');
  },
  load: async () => (await import('./index')).createVercelAdapter,
  vendorDecides: (value) => {
    vendor.value = value;
  },
  evaluatedKeys: () => vendor.keys,
  vendorInitialised: () => vendor.built > 0,
  requiredConfig: [{ name: 'FLAGS', remove: () => vi.stubEnv('FLAGS', '') }],
});
