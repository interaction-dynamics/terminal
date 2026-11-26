import type Stripe from 'stripe';
import { vi } from 'vitest';
import type { Plan } from '../_types/plan';
import { describePaymentContract } from '../payment.contract';

const vendor = vi.hoisted(() => ({
  prices: [] as unknown[],
  checkoutUrl: null as string | null,
  sessions: new Map<string, unknown>(),
  checkoutPriceIds: [] as string[],
  calls: 0,
  fails: false,
  reportedErrors: [] as unknown[],
}));

/** Every stubbed endpoint counts the call and honours `failRequests`. */
const endpoint =
  <Args extends unknown[], Result>(answer: (...args: Args) => Result) =>
  async (...args: Args) => {
    vendor.calls += 1;
    if (vendor.fails) throw new Error('Stripe is unreachable');
    return answer(...args);
  };

// Keep the real client and replace only the endpoints the adapter calls.
vi.mock('stripe', async (importOriginal) => {
  const { default: RealStripe } = await importOriginal<{ default: typeof Stripe }>();
  const StubbedStripe = class extends RealStripe {
    constructor(key: string) {
      super(key);
      Object.assign(this.prices, { list: endpoint(() => ({ data: vendor.prices })) });
      Object.assign(this.checkout.sessions, {
        create: endpoint((params: Stripe.Checkout.SessionCreateParams) => {
          vendor.checkoutPriceIds.push(params.line_items?.[0]?.price ?? '');
          return { url: vendor.checkoutUrl };
        }),
        retrieve: endpoint((id: string) => vendor.sessions.get(id)),
      });
    }
  };
  // The SDK exposes the client both as the default and as the named `Stripe` export.
  return { default: StubbedStripe, Stripe: StubbedStripe };
});
vi.mock('next/headers', () => ({
  headers: async () => new Headers({ origin: 'https://app.test' }),
}));
vi.mock('@ship-it/adapters/monitoring', () => ({
  logError: (_message: string, error: unknown) => vendor.reportedErrors.push(error),
}));

const toPrice = (plan: Plan) => ({
  id: plan.price_id,
  unit_amount: plan.price,
  recurring: plan.interval ? { interval: plan.interval } : null,
  product:
    plan.productName === null
      ? { id: 'prod_gone', deleted: true }
      : { id: 'prod_live', name: plan.productName, deleted: undefined },
  currency: 'usd',
  livemode: false,
});

describePaymentContract('Stripe', {
  configure: () => {
    Object.assign(vendor, {
      prices: [],
      checkoutUrl: null,
      sessions: new Map(),
      checkoutPriceIds: [],
      calls: 0,
      fails: false,
      reportedErrors: [],
    });
    vi.stubEnv('STRIPE_SECRET_KEY', 'sk_test_contract');
  },
  load: () => import('./index'),
  givenPlans: (plans) => {
    vendor.prices = plans.map(toPrice);
  },
  givenCheckoutUrl: (url) => {
    vendor.checkoutUrl = url;
  },
  givenPaymentSession: (id, { status, customerEmail }) => {
    vendor.sessions.set(id, {
      id,
      status,
      customer_email: customerEmail,
      payment_status: 'paid',
      livemode: false,
    });
  },
  checkoutPriceIds: () => vendor.checkoutPriceIds,
  failRequests: () => {
    vendor.fails = true;
  },
  vendorCalls: () => vendor.calls,
  reportedErrors: () => vendor.reportedErrors,
  requiredConfig: [
    { name: 'STRIPE_SECRET_KEY', remove: () => vi.stubEnv('STRIPE_SECRET_KEY', '') },
  ],
});
