import { render, screen } from '@testing-library/react';
import type { createPaymentCheckoutSession } from '@ship-it/adapters/payment';
import { describe, expect, it, vi } from 'vitest';
import { CheckoutForm } from '../checkout-form';

vi.mock('@ship-it/adapters/payment', () => ({
  createPaymentCheckoutSession: vi.fn<typeof createPaymentCheckoutSession>(),
}));

const plan = {
  id: 'price_1',
  productName: 'Pro',
  price: 1500,
  interval: 'month',
  price_id: 'price_1',
};

describe('CheckoutForm', () => {
  it('shows the product name and price', () => {
    render(<CheckoutForm plans={[plan]} />);

    expect(screen.getByRole('heading', { name: 'Pro' })).toBeInTheDocument();
    expect(screen.getByText(/15 \/ month/)).toBeInTheDocument();
  });

  it('labels a plan whose product no longer exists', () => {
    render(<CheckoutForm plans={[{ ...plan, productName: null }]} />);

    expect(screen.getByRole('heading', { name: 'deleted product' })).toBeInTheDocument();
  });
});
