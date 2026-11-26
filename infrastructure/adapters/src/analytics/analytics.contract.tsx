import type { ComponentType } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

export interface AnalyticsContractHarness {
  /** Sets the tracking id the vendor needs. `NODE_ENV` is handled by the contract. */
  configure: () => void;
  /** Imports a fresh copy of the vendor's script component. */
  load: () => Promise<ComponentType>;
  /** The tracking id `configure` sets, which the rendered script must carry. */
  trackingId: string;
  /** Config without which the vendor must load no script (ADR 0021), and how to remove it. */
  requiredConfig: { name: string; remove: () => void }[];
}

const renderScript = async (harness: AnalyticsContractHarness) => {
  const Script = await harness.load();
  return renderToStaticMarkup(<Script />);
};

/**
 * Behaviour every analytics script must share so `AnalyticsScript` can mount them side by side.
 * Call it from `<vendor>/<vendor>.contract.test.tsx` with `next/script` mocked.
 */
export function describeAnalyticsContract(vendor: string, harness: AnalyticsContractHarness): void {
  describe(`${vendor} analytics adapter contract`, () => {
    beforeEach(() => {
      vi.resetModules();
      vi.stubEnv('NODE_ENV', 'production');
      harness.configure();
    });

    afterEach(() => {
      vi.unstubAllEnvs();
      vi.resetAllMocks();
    });

    it('loads the vendor script with the tracking id in production', async () => {
      await expect(renderScript(harness)).resolves.toContain(harness.trackingId);
    });

    it.each(['development', 'test'])('loads nothing when NODE_ENV is %s', async (env) => {
      vi.stubEnv('NODE_ENV', env);

      await expect(renderScript(harness)).resolves.toBe('');
    });

    describe.each(harness.requiredConfig)('without $name', ({ remove }) => {
      it('loads nothing', async () => {
        remove();

        await expect(renderScript(harness)).resolves.toBe('');
      });
    });
  });
}
