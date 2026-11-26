import { vi } from 'vitest';
import { describeAnalyticsContract } from '../analytics.contract';

vi.mock('@next/third-parties/google', () => ({
  GoogleAnalytics: ({ gaId }: { gaId: string }) => <script data-ga-id={gaId} />,
}));

describeAnalyticsContract('Google Analytics', {
  configure: () => vi.stubEnv('NEXT_PUBLIC_GOOGLE_ANALYTICS_ID', 'G-TEST123'),
  load: async () => (await import('./index')).GoogleProvider,
  trackingId: 'G-TEST123',
  requiredConfig: [
    {
      name: 'NEXT_PUBLIC_GOOGLE_ANALYTICS_ID',
      remove: () => vi.stubEnv('NEXT_PUBLIC_GOOGLE_ANALYTICS_ID', ''),
    },
  ],
});
