import type { Adapter } from 'flags';

/**
 * Port for boolean feature flags: given a flag key and the incoming request,
 * decide whether the flag is on.
 *
 * Only `decide` is part of the contract. Each provider identifies its audience
 * differently — a PostHog distinct id, a Statsig user — and none of those
 * shapes crosses this boundary, which is what keeps the implementations
 * interchangeable for the feature code declaring the flag.
 */
export type BooleanFlagAdapter = Pick<Adapter<boolean, never>, 'decide'>;

/**
 * Builds a provider's adapter.
 *
 * Providers are optional: when one is not configured its factory returns an
 * adapter that keeps `fallback` instead of failing.
 */
export type CreateBooleanFlagAdapter = (fallback?: boolean) => BooleanFlagAdapter;
