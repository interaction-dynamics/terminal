import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

type Message = Record<string, unknown>;

const messagesCreate = vi.hoisted(() =>
  vi.fn<(domain: string, message: Message) => Promise<unknown>>(),
);
const resendSend = vi.hoisted(() => vi.fn<(message: Message) => Promise<{ error: unknown }>>());

vi.mock('mailgun.js', () => ({
  default: class {
    client() {
      return { messages: { create: messagesCreate } };
    }
  },
}));

vi.mock('resend', () => ({
  Resend: class {
    emails = { send: resendSend };
  },
}));

import { getProvider, isEmailConfigured } from './index';

const plainEmail = { to: ['user@example.com'], subject: 'Hi', text: 'Hello', html: '<p>Hello</p>' };
const formattedEmail = { to: ['user@example.com'], subject: 'Hi', react: <p>Hello</p> };

describe('email getProvider', () => {
  beforeEach(() => {
    vi.stubEnv('RESEND_API_KEY', '');
    vi.stubEnv('RESEND_EMAIL_FROM', '');
    vi.stubEnv('MAILGUN_API_KEY', '');
    vi.stubEnv('MAILGUN_DOMAIN', '');
    vi.stubEnv('MAILGUN_EMAIL_FROM', '');
    resendSend.mockResolvedValue({ error: null });
    messagesCreate.mockResolvedValue({});
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.resetAllMocks();
  });

  it.each(['RESEND_API_KEY', 'MAILGUN_API_KEY'])('reports configured when %s is set', (name) => {
    expect(isEmailConfigured()).toBe(false);

    vi.stubEnv(name, 'key');

    expect(isEmailConfigured()).toBe(true);
  });

  describe('with no vendor configured', () => {
    it('drops both email types without calling a vendor', async () => {
      const { sendEmail, sendFormattedEmail } = await getProvider();

      await expect(sendEmail(plainEmail)).resolves.toBeUndefined();
      await expect(sendFormattedEmail(formattedEmail)).resolves.toBeUndefined();
      expect(messagesCreate).not.toHaveBeenCalled();
      expect(resendSend).not.toHaveBeenCalled();
    });
  });

  describe('with only Mailgun configured', () => {
    beforeEach(() => {
      vi.stubEnv('MAILGUN_API_KEY', 'key');
      vi.stubEnv('MAILGUN_DOMAIN', 'mg.example.com');
    });

    it('sends plain emails through Mailgun', async () => {
      const { sendEmail } = await getProvider();

      await sendEmail(plainEmail);

      expect(messagesCreate).toHaveBeenCalledWith('mg.example.com', {
        ...plainEmail,
        from: 'postmaster@mg.example.com',
      });
    });

    it('renders formatted emails and sends them through Mailgun', async () => {
      const { sendFormattedEmail } = await getProvider();

      await sendFormattedEmail(formattedEmail);

      const call = messagesCreate.mock.calls[0];
      if (!call) throw new Error('expected Mailgun messages.create to have been called');
      const [, message] = call;
      expect(message.html).toContain('<p>Hello</p>');
      expect(message.text).toContain('Hello');
      expect(message).not.toHaveProperty('react');
    });

    it('rejects when Mailgun rejects', async () => {
      messagesCreate.mockRejectedValue(new Error('unauthorized'));
      const { sendEmail, sendFormattedEmail } = await getProvider();

      await expect(sendEmail(plainEmail)).rejects.toThrow('unauthorized');
      await expect(sendFormattedEmail(formattedEmail)).rejects.toThrow('unauthorized');
    });

    it('prefers the email from, then MAILGUN_EMAIL_FROM', async () => {
      vi.stubEnv('MAILGUN_EMAIL_FROM', 'App <hello@example.com>');
      const { sendEmail } = await getProvider();

      await sendEmail(plainEmail);
      await sendEmail({ ...plainEmail, from: 'other@example.com' });

      expect(messagesCreate.mock.calls.map(([, message]) => message.from)).toEqual([
        'App <hello@example.com>',
        'other@example.com',
      ]);
    });

    it('rejects when MAILGUN_DOMAIN is missing', async () => {
      vi.stubEnv('MAILGUN_DOMAIN', '');
      const { sendEmail } = await getProvider();

      await expect(sendEmail(plainEmail)).rejects.toThrow('MAILGUN_DOMAIN');
      expect(messagesCreate).not.toHaveBeenCalled();
    });
  });

  describe('with only Resend configured', () => {
    beforeEach(() => {
      vi.stubEnv('RESEND_API_KEY', 'key');
      vi.stubEnv('RESEND_EMAIL_FROM', 'hello@example.com');
    });

    it('sends plain emails through Resend', async () => {
      const { sendEmail } = await getProvider();

      await sendEmail(plainEmail);

      expect(resendSend).toHaveBeenCalledWith({ ...plainEmail, from: 'hello@example.com' });
    });

    it('sends formatted emails through Resend', async () => {
      const { sendFormattedEmail } = await getProvider();

      await sendFormattedEmail(formattedEmail);

      expect(resendSend).toHaveBeenCalledWith({ ...formattedEmail, from: 'hello@example.com' });
    });

    it('rejects when Resend reports an error', async () => {
      const error = { name: 'validation_error', message: 'bad from' };
      resendSend.mockResolvedValue({ error });
      const { sendEmail, sendFormattedEmail } = await getProvider();

      const sending = sendEmail(plainEmail);
      await expect(sending).rejects.toThrow('bad from');
      await expect(sending).rejects.toHaveProperty('cause', error);
      const sendingFormatted = sendFormattedEmail(formattedEmail);
      await expect(sendingFormatted).rejects.toThrow('bad from');
      await expect(sendingFormatted).rejects.toHaveProperty('cause', error);
    });
  });

  describe('with both vendors configured', () => {
    it('sends both email types through Resend', async () => {
      vi.stubEnv('RESEND_API_KEY', 'key');
      vi.stubEnv('MAILGUN_API_KEY', 'key');
      vi.stubEnv('MAILGUN_DOMAIN', 'mg.example.com');
      const { sendEmail, sendFormattedEmail } = await getProvider();

      await sendEmail(plainEmail);
      await sendFormattedEmail(formattedEmail);

      expect(resendSend).toHaveBeenCalledTimes(2);
      expect(messagesCreate).not.toHaveBeenCalled();
    });
  });
});
