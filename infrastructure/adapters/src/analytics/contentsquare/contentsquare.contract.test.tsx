import { vi } from 'vitest';
import { describeAnalyticsContract } from '../analytics.contract';

vi.mock('next/script', () => import('../next-script.mock'));

describeAnalyticsContract('Contentsquare', {
  configure: () => vi.stubEnv('NEXT_PUBLIC_CONTENTSQUARE_ID', 'cs-123'),
  load: async () => (await import('./index')).ContentSquare,
  trackingId: 'cs-123',
  requiredConfig: [
    {
      name: 'NEXT_PUBLIC_CONTENTSQUARE_ID',
      remove: () => vi.stubEnv('NEXT_PUBLIC_CONTENTSQUARE_ID', ''),
    },
  ],
});
