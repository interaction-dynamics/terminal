'use server';
import { headers } from 'next/headers';
import { Stripe } from 'stripe';
import { logError } from '@ship-it/adapters/monitoring';
import type { Plan } from '../_types/plan';
import type { CheckoutSession, PaymentSession } from '../_types/session';
import { toCheckoutSession, toPaymentSession, toPlan } from './mappers';
import { paymentEnv } from '../env';

const { STRIPE_SECRET_KEY } = paymentEnv();
const stripe = STRIPE_SECRET_KEY ? new Stripe(STRIPE_SECRET_KEY) : null;

const getStripe = () => {
  if (!stripe) {
    throw new Error(`Stripe is not configured. Please set environment variable STRIPE_SECRET_KEY`);
  }

  return stripe;
};

export async function checkPaymentSession(sessionId: string): Promise<PaymentSession | null> {
  try {
    const session = await getStripe().checkout.sessions.retrieve(sessionId);

    if (session.payment_status === 'paid') {
      // Update your database to mark the user as subscribed
      // await updateUserSubscriptionStatus(session.client_reference_id, 'active');
    }

    return toPaymentSession(session);
  } catch (error: unknown) {
    logError('Failed to check payment session', error);
    return null;
  }
}

export async function createPaymentCheckoutSession(
  priceId: string,
): Promise<CheckoutSession | null> {
  const origin = (await headers()).get('origin') ?? '';

  try {
    const session = await getStripe().checkout.sessions.create({
      mode: 'subscription',
      allowed_payment_method_types: ['card'],
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      success_url: `${origin}/checkout/success?sessionId={CHECKOUT_SESSION_ID}`,
      cancel_url: `${origin}/checkout`,
    });

    return toCheckoutSession(session);
  } catch (error) {
    logError('Failed to check payment session', error);
    return null;
  }
}

export async function getPlans(): Promise<Plan[]> {
  try {
    const prices = await getStripe().prices.list({
      expand: ['data.product'],
      active: true,
      type: 'recurring',
    });

    return prices.data.map(toPlan);
  } catch (error) {
    logError('Failed to check payment session', error);
    return [];
  }
}
