import { vi } from 'vitest';
import { describeAnalyticsContract } from '../analytics.contract';

vi.mock('next/script', () => import('../next-script.mock'));

describeAnalyticsContract('Hotjar', {
  configure: () => vi.stubEnv('NEXT_PUBLIC_HOTJAR_ID', '4242'),
  load: async () => (await import('./index')).HotJar,
  trackingId: 'hjid: 4242',
  requiredConfig: [
    { name: 'NEXT_PUBLIC_HOTJAR_ID', remove: () => vi.stubEnv('NEXT_PUBLIC_HOTJAR_ID', '') },
  ],
});
