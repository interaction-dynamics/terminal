import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Plan } from './_types/plan';
import type { CheckoutSession, PaymentSession } from './_types/session';

/**
 * The functions `@ship-it/adapters/payment` exposes. Payment has no `interfaces.ts` yet, so the
 * contract spells the port out here.
 */
interface PaymentPort {
  getPlans: () => Promise<Plan[]>;
  createPaymentCheckoutSession: (priceId: string) => Promise<CheckoutSession | null>;
  checkPaymentSession: (sessionId: string) => Promise<PaymentSession | null>;
}

export interface PaymentContractHarness {
  /** Sets the env vars and SDK mock defaults the vendor needs. Runs before each test. */
  configure: () => void;
  /** Imports a fresh copy of the adapter so it reads the current configuration. */
  load: () => Promise<PaymentPort>;
  /** Makes the mocked vendor list these plans, translated into its own shapes. */
  givenPlans: (plans: Plan[]) => void;
  /** Makes the mocked vendor open checkouts at `url`. */
  givenCheckoutUrl: (url: string) => void;
  /** Makes the mocked vendor report this checkout outcome for `sessionId`. */
  givenPaymentSession: (sessionId: string, session: PaymentSession) => void;
  /** Price ids the mocked vendor was asked to open a checkout for. */
  checkoutPriceIds: () => string[];
  /** Makes every call to the mocked vendor fail, as on an outage or a revoked key. */
  failRequests: () => void;
  /** How many calls reached the mocked vendor. */
  vendorCalls: () => number;
  /** Errors the adapter reported to monitoring. */
  reportedErrors: () => unknown[];
  /** Config without which the adapter must not reach the vendor (ADR 0021), and how to remove it. */
  requiredConfig: { name: string; remove: () => void }[];
}

const plans: Plan[] = [
  { id: 'price_pro', productName: 'Pro', price: 1900, interval: 'month', price_id: 'price_pro' },
  { id: 'price_old', productName: null, price: null, interval: undefined, price_id: 'price_old' },
];

/**
 * Behaviour every payment vendor must share so feature code can swap them.
 * Call it from `<vendor>/<vendor>.contract.test.ts` with the vendor SDK mocked.
 */
export function describePaymentContract(vendor: string, harness: PaymentContractHarness): void {
  describe(`${vendor} payment adapter contract`, () => {
    beforeEach(() => {
      vi.resetModules();
      harness.configure();
    });

    afterEach(() => {
      vi.unstubAllEnvs();
      vi.resetAllMocks();
    });

    it('lists plans in domain terms only', async () => {
      harness.givenPlans(plans);
      const { getPlans } = await harness.load();

      await expect(getPlans()).resolves.toStrictEqual(plans);
    });

    it('opens a checkout for the chosen price', async () => {
      harness.givenCheckoutUrl('https://pay.example.com/c/123');
      const { createPaymentCheckoutSession } = await harness.load();

      await expect(createPaymentCheckoutSession('price_pro')).resolves.toStrictEqual({
        url: 'https://pay.example.com/c/123',
      });
      expect(harness.checkoutPriceIds()).toEqual(['price_pro']);
    });

    it('reports the outcome of a checkout in domain terms only', async () => {
      const outcome = { status: 'complete', customerEmail: 'user@example.com' };
      harness.givenPaymentSession('cs_123', outcome);
      const { checkPaymentSession } = await harness.load();

      await expect(checkPaymentSession('cs_123')).resolves.toStrictEqual(outcome);
    });

    it('returns nothing and reports the error when the vendor fails', async () => {
      harness.failRequests();
      const { getPlans, createPaymentCheckoutSession, checkPaymentSession } = await harness.load();

      await expect(getPlans()).resolves.toEqual([]);
      await expect(createPaymentCheckoutSession('price_pro')).resolves.toBeNull();
      await expect(checkPaymentSession('cs_123')).resolves.toBeNull();
      expect(harness.reportedErrors()).toHaveLength(3);
    });

    describe.each(harness.requiredConfig)('without $name', ({ remove }) => {
      it('opens no checkout and reports the error without reaching the vendor', async () => {
        remove();
        const { getPlans, createPaymentCheckoutSession, checkPaymentSession } =
          await harness.load();

        await expect(getPlans()).resolves.toEqual([]);
        await expect(createPaymentCheckoutSession('price_pro')).resolves.toBeNull();
        await expect(checkPaymentSession('cs_123')).resolves.toBeNull();
        expect(harness.vendorCalls()).toBe(0);
        expect(harness.reportedErrors()).toHaveLength(3);
      });
    });
  });
}
