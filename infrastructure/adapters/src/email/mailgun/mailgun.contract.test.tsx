import { vi } from 'vitest';
import { describeEmailContract } from '../email.contract';

type Message = { from?: string; to: string[]; subject: string; text: string; html: string };

const messagesCreate = vi.hoisted(() =>
  vi.fn<(domain: string, message: Message) => Promise<unknown>>(),
);

// Keep the real client, so its own config checks run, and replace only the network call.
vi.mock('mailgun.js', async (importOriginal) => {
  const { default: Mailgun } = await importOriginal<typeof import('mailgun.js')>();
  return {
    default: class extends Mailgun {
      override client(options: Parameters<InstanceType<typeof Mailgun>['client']>[0]) {
        const client = super.client(options);
        client.messages.create = messagesCreate as never;
        return client;
      }
    },
  };
});

describeEmailContract('Mailgun', {
  configure: () => {
    vi.stubEnv('MAILGUN_API_KEY', 'test-key');
    vi.stubEnv('MAILGUN_DOMAIN', 'mg.example.com');
    vi.stubEnv('MAILGUN_EMAIL_FROM', 'App <hello@example.com>');
    messagesCreate.mockResolvedValue({ status: 200 });
  },
  load: () => import('./index'),
  delivered: async () =>
    messagesCreate.mock.calls.map(([, { from, to, subject, text, html }]) => ({
      from,
      to,
      subject,
      body: `${text}\n${html}`,
    })),
  failDelivery: (message) => messagesCreate.mockRejectedValue(new Error(message)),
  defaultFrom: 'App <hello@example.com>',
  requiredConfig: [
    { name: 'MAILGUN_API_KEY', remove: () => vi.stubEnv('MAILGUN_API_KEY', '') },
    { name: 'MAILGUN_DOMAIN', remove: () => vi.stubEnv('MAILGUN_DOMAIN', '') },
  ],
});
