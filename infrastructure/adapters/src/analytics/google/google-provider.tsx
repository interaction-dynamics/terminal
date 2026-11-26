import { GoogleAnalytics } from '@next/third-parties/google';
import { analyticsEnv } from '../env';

export function GoogleProvider() {
  const { NODE_ENV, NEXT_PUBLIC_GOOGLE_ANALYTICS_ID: gaId } = analyticsEnv();

  if (NODE_ENV === 'production' && gaId) {
    return <GoogleAnalytics gaId={gaId} />;
  }

  return null;
}
