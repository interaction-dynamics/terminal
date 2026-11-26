/** A checkout the user can be redirected to. */
export interface CheckoutSession {
  url: string | null;
}

/** The outcome of a checkout, as shown to the user afterwards. */
export interface PaymentSession {
  status: string | null;
  customerEmail: string | null;
}
