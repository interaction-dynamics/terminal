import { vi } from 'vitest';
import {
  describeNotificationContract,
  type DeliveredNotification,
} from '../notifications.contract';

type SlackBody = { channel?: string; blocks: { text: { text: string } }[] };

const delivered: DeliveredNotification[] = [];
let status = 200;

/** Stands in for the webhook: validates the URL as `fetch` does, then answers with `status`. */
const fakeFetch = async (url: string | URL | Request, init?: RequestInit) => {
  const href = url instanceof Request ? url.url : url.toString();
  if (!URL.canParse(href)) throw new TypeError(`Invalid URL: ${href}`);
  if (status === 200) {
    if (typeof init?.body !== 'string') throw new TypeError('Expected a JSON string body');
    const { channel, blocks } = JSON.parse(init.body) as SlackBody;
    delivered.push({ channel, text: blocks.map((block) => block.text.text).join('\n') });
  }
  return new Response(null, { status, statusText: status === 200 ? 'OK' : 'Forbidden' });
};

describeNotificationContract('Slack', {
  configure: () => {
    delivered.length = 0;
    status = 200;
    vi.stubEnv('SLACK_WEBHOOK_URL', 'https://hooks.slack.test/services/T000/B000/XXX');
    vi.stubGlobal('fetch', vi.fn(fakeFetch));
  },
  load: () => import('./index'),
  delivered: () => delivered,
  failDelivery: () => {
    status = 403;
  },
  requiredConfig: [
    { name: 'SLACK_WEBHOOK_URL', remove: () => vi.stubEnv('SLACK_WEBHOOK_URL', '') },
  ],
});
