import { vercelAdapter } from '@flags-sdk/vercel';
import { createBlankAdapter } from '../blank';
import type { BooleanFlagAdapter } from '../interfaces';
import { experimentationEnv } from '../env';

/**
 * `FLAGS` holds the Vercel flags SDK key. The adapter throws without it, so the
 * provider is only used once configured.
 */
const isConfigured = (): boolean => Boolean(experimentationEnv().FLAGS);

export const createVercelAdapter = (fallback = false): BooleanFlagAdapter =>
  isConfigured() ? vercelAdapter<boolean, unknown>() : createBlankAdapter(fallback);
