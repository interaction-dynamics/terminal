import type Stripe from 'stripe';
import type { Plan } from '../_types/plan';
import type { CheckoutSession, PaymentSession } from '../_types/session';

const toProductName = (product: Stripe.Price['product']): string | null => {
  if (typeof product === 'string') {
    return product;
  }

  return product.deleted ? null : product.name;
};

export const toPlan = (price: Stripe.Price): Plan => ({
  id: price.id,
  productName: toProductName(price.product),
  price: price.unit_amount,
  interval: price.recurring?.interval,
  price_id: price.id,
});

export const toCheckoutSession = (session: Stripe.Checkout.Session): CheckoutSession => ({
  url: session.url,
});

export const toPaymentSession = (session: Stripe.Checkout.Session): PaymentSession => ({
  status: session.status,
  customerEmail: session.customer_email,
});
