export interface Plan {
  id: string;
  /** `null` when the product no longer exists. */
  productName: string | null;
  price: number | null;
  interval: string | undefined;
  price_id: string;
}
