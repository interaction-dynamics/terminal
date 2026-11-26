import { statsigAdapter } from '@flags-sdk/statsig';
import { createBlankAdapter } from '../blank';
import type { BooleanFlagAdapter } from '../interfaces';
import { experimentationEnv } from '../env';

/**
 * Statsig initialises its SDK when an adapter is created and throws without a
 * server API key, so the provider is only used once configured.
 */
const isConfigured = (): boolean => Boolean(experimentationEnv().STATSIG_SERVER_API_KEY);

export const createStatsigAdapter = (fallback = false): BooleanFlagAdapter =>
  isConfigured() ? statsigAdapter.featureGate((gate) => gate.value) : createBlankAdapter(fallback);
