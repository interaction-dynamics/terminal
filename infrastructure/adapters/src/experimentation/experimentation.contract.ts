import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { BooleanFlagAdapter, CreateBooleanFlagAdapter } from './interfaces';

export interface ExperimentationContractHarness {
  /** Sets the env vars that let the vendor evaluate flags. Runs before each test. */
  configure: () => void;
  /** Imports a fresh copy of the adapter factory so it reads the current configuration. */
  load: () => Promise<CreateBooleanFlagAdapter>;
  /** Makes the mocked vendor SDK evaluate every flag to `value`. */
  vendorDecides: (value: boolean) => void;
  /** Flag keys the mocked vendor SDK was asked to evaluate. */
  evaluatedKeys: () => string[];
  /** Whether the vendor SDK was set up, which may open connections or throw without config. */
  vendorInitialised: () => boolean;
  /** Config without which the adapter must keep the flag's default (ADR 0021), and how to remove it. */
  requiredConfig: { name: string; remove: () => void }[];
}

type DecideParams = Parameters<BooleanFlagAdapter['decide']>[0];

// The port lets `decide` answer synchronously or not, so always compare a promise.
const decide = async (adapter: BooleanFlagAdapter, params: Partial<DecideParams> = {}) =>
  adapter.decide({
    key: 'new-checkout',
    headers: new Headers(),
    cookies: {} as DecideParams['cookies'],
    ...params,
  });

/**
 * Behaviour every boolean feature flag vendor must share so flags can move between them.
 * Call it from `<vendor>/<vendor>.contract.test.ts` with the vendor SDK mocked.
 */
export function describeExperimentationContract(
  vendor: string,
  harness: ExperimentationContractHarness,
): void {
  describe(`${vendor} experimentation adapter contract`, () => {
    beforeEach(() => {
      vi.resetModules();
      harness.configure();
    });

    afterEach(() => {
      vi.unstubAllEnvs();
      vi.resetAllMocks();
    });

    it.each([true, false])('returns the vendor decision (%s) over the default', async (value) => {
      harness.vendorDecides(value);
      const createAdapter = await harness.load();

      await expect(decide(createAdapter(!value), { defaultValue: !value })).resolves.toBe(value);
    });

    it('asks the vendor about the flag being decided', async () => {
      harness.vendorDecides(true);
      const createAdapter = await harness.load();

      await decide(createAdapter(), { key: 'new-checkout' });

      expect(harness.evaluatedKeys()).toEqual(['new-checkout']);
    });

    describe.each(harness.requiredConfig)('without $name', ({ remove }) => {
      beforeEach(() => {
        remove();
        harness.vendorDecides(true);
      });

      it('keeps the flag default without setting up the vendor SDK', async () => {
        const createAdapter = await harness.load();

        await expect(decide(createAdapter(), { defaultValue: false })).resolves.toBe(false);
        expect(harness.vendorInitialised()).toBe(false);
      });

      it('falls back to the factory fallback when the flag has no default', async () => {
        const createAdapter = await harness.load();

        await expect(decide(createAdapter(true))).resolves.toBe(true);
        await expect(decide(createAdapter(false))).resolves.toBe(false);
      });
    });
  });
}
