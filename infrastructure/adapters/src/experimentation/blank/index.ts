import type { BooleanFlagAdapter } from '../interfaces';

/**
 * Adapter used when no provider is configured. It keeps the flag's declared
 * default value so the app runs without any feature flag environment variable.
 */
export const createBlankAdapter = (fallback = false): BooleanFlagAdapter => ({
  decide: ({ defaultValue }) => (typeof defaultValue === 'boolean' ? defaultValue : fallback),
});
