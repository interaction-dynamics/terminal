import { render, toPlainText } from '@react-email/components';
import type { ReactNode } from 'react';
import { vi } from 'vitest';
import { describeEmailContract } from '../email.contract';

type Message = {
  from: string;
  to: string[];
  subject: string;
  text?: string;
  html?: string;
  react?: ReactNode;
};

const send = vi.hoisted(() =>
  vi.fn<(message: Message) => Promise<{ data: unknown; error: unknown }>>(),
);

// Keep the real client, so its own config checks run, and replace only the network call.
vi.mock('resend', async (importOriginal) => {
  const actual = await importOriginal<typeof import('resend')>();
  return {
    ...actual,
    Resend: class extends actual.Resend {
      constructor(key?: string) {
        super(key);
        this.emails.send = send as never;
      }
    },
  };
});

const bodyOf = async ({ text, html, react }: Message) => {
  if (react === undefined) return `${text}\n${html}`;
  return toPlainText(await render(react));
};

describeEmailContract('Resend', {
  configure: () => {
    vi.stubEnv('RESEND_API_KEY', 're_test');
    vi.stubEnv('RESEND_EMAIL_FROM', 'App <hello@example.com>');
    send.mockResolvedValue({ data: { id: 'email-id' }, error: null });
  },
  load: () => import('./index'),
  delivered: () =>
    Promise.all(
      send.mock.calls.map(async ([message]) => ({
        from: message.from,
        to: message.to,
        subject: message.subject,
        body: await bodyOf(message),
      })),
    ),
  // Resend resolves with an error object instead of rejecting.
  failDelivery: (message) =>
    send.mockResolvedValue({ data: null, error: { name: 'validation_error', message } }),
  defaultFrom: 'App <hello@example.com>',
  requiredConfig: [{ name: 'RESEND_API_KEY', remove: () => vi.stubEnv('RESEND_API_KEY', '') }],
});
