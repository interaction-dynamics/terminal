'use client';

import { createPaymentCheckoutSession, type Plan } from '@ship-it/adapters/payment';
import { Button } from '@/components/ui/button';

interface CheckoutFormProps {
  plans: Plan[];
}

const handleSubmit = async (priceId: string) => {
  const session = await createPaymentCheckoutSession(priceId);

  if (!session?.url) {
    return;
  }

  window.location.assign(session.url);
};

export function CheckoutForm({ plans }: CheckoutFormProps) {
  return (
    <div>
      <h1>Choose a Subscription Plan</h1>
      {plans.map((plan) => (
        <div key={plan.id}>
          <h2>{plan.productName ?? 'deleted product'}</h2>
          <p>
            Price: ${(plan.price ?? 0) / 100} / {plan.interval}
          </p>
          <Button onClick={() => void handleSubmit(plan.price_id)}>Subscribe</Button>
        </div>
      ))}
    </div>
  );
}
