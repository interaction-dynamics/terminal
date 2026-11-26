import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Monitoring, RegisterTelemetry } from './interfaces';

export interface ErrorLoggingContractHarness {
  /** Sets the env vars and SDK mock defaults the vendor needs. Runs before each test. */
  configure: () => void;
  /** Imports a fresh copy of the adapter so it reads the current configuration. */
  load: () => Promise<Pick<Monitoring, 'logError'>>;
  /** Errors the mocked vendor received. */
  logged: () => { message: string; error: unknown }[];
}

/**
 * Behaviour every error-logging vendor must share so feature code can swap them.
 * Call it from `<vendor>/<vendor>.contract.test.ts` with the vendor SDK mocked.
 */
export function describeErrorLoggingContract(
  vendor: string,
  harness: ErrorLoggingContractHarness,
): void {
  describe(`${vendor} error logging adapter contract`, () => {
    beforeEach(() => {
      vi.resetModules();
      harness.configure();
    });

    afterEach(() => {
      vi.unstubAllEnvs();
      vi.restoreAllMocks();
      vi.resetAllMocks();
    });

    it('hands the message and the original error to the vendor', async () => {
      const { logError } = await harness.load();
      const error = new Error('payment declined');

      logError('Checkout failed', error);

      expect(harness.logged()).toEqual([{ message: 'Checkout failed', error }]);
    });

    it('returns without waiting, so callers can log from a catch block and carry on', async () => {
      const { logError } = await harness.load();

      expect(logError('Checkout failed', 'not an Error instance')).toBeUndefined();
    });
  });
}

export interface TelemetryContractHarness {
  /** Imports a fresh copy of the adapter. */
  load: () => Promise<RegisterTelemetry>;
  /** Service names the mocked vendor SDK was registered with. */
  registeredServices: () => (string | undefined)[];
}

/** Behaviour every tracing vendor must share. */
export function describeTelemetryContract(vendor: string, harness: TelemetryContractHarness): void {
  describe(`${vendor} telemetry adapter contract`, () => {
    beforeEach(() => {
      vi.resetModules();
    });

    afterEach(() => {
      vi.resetAllMocks();
    });

    it('registers tracing under the given service name', async () => {
      const registerTelemetry = await harness.load();

      registerTelemetry('ship-it-web');

      expect(harness.registeredServices()).toEqual(['ship-it-web']);
    });
  });
}
