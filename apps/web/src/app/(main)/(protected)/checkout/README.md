---
feature: true
# TODO: owner
creation_date: 2026-03-06
---

# Checkout

Lets a signed-in user pay for a plan and see whether the payment succeeded.

## How it works

- `/checkout` (`page.tsx`) loads the plans from the payment adapter (`@ship-it/adapters/payment`) and renders `CheckoutForm` (`_components/`), which opens the provider's checkout session.
- `/checkout/success` (`success/page.tsx`) reads the `sessionId` returned by the provider and shows whether the payment succeeded, failed or is still processing.
