import Script from 'next/script';
import { analyticsEnv } from '../env';

export function ContentSquare() {
  const { NODE_ENV, NEXT_PUBLIC_CONTENTSQUARE_ID: siteId } = analyticsEnv();

  if (NODE_ENV === 'production' && siteId) {
    return <Script src={`https://t.contentsquare.net/uxa/${siteId}.js`} async />;
  }
  return null;
}
