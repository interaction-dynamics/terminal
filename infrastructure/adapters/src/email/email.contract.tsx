import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Email, EmailProvider, FormattedEmail } from './interfaces';

/** An email as the vendor received it, translated back into port terms. */
interface DeliveredEmail {
  from?: string;
  to: string[];
  subject: string;
  /** Text and HTML the recipient sees, rendered if the vendor was handed React. */
  body: string;
}

export interface EmailContractHarness {
  /** Sets the env vars and SDK mock defaults that let the vendor send. Runs before each test. */
  configure: () => void;
  /** Imports a fresh copy of the adapter so it reads the current configuration. */
  load: () => Promise<EmailProvider>;
  /** Emails the mocked SDK was asked to send. */
  delivered: () => Promise<DeliveredEmail[]>;
  /** Makes the mocked SDK report a failure with this message, as the API does for a bad key. */
  failDelivery: (message: string) => void;
  /** The sender the adapter uses when the email has no `from`, given `configure`. */
  defaultFrom: string;
  /** Config without which the adapter must refuse to send (ADR 0021), and how to remove it. */
  requiredConfig: { name: string; remove: () => void }[];
}

const plainEmail: Email = {
  to: ['user@example.com'],
  subject: 'Welcome',
  text: 'Hello from the contract',
  html: '<p>Hello from the contract</p>',
};

/** What the recipient must see from either email. */
const body: unknown = expect.stringContaining('Hello from the contract');

const formattedEmail: FormattedEmail = {
  to: ['user@example.com'],
  subject: 'Welcome',
  react: <p>Hello from the contract</p>,
};

/**
 * Behaviour every `EmailProvider` vendor must share so feature code can swap them.
 * Call it from `<vendor>/<vendor>.contract.test.tsx` with the vendor SDK mocked.
 */
export function describeEmailContract(vendor: string, harness: EmailContractHarness): void {
  describe(`${vendor} email adapter contract`, () => {
    beforeEach(() => {
      vi.resetModules();
      harness.configure();
    });

    afterEach(() => {
      vi.unstubAllEnvs();
      vi.resetAllMocks();
    });

    it('delivers a plain email to every recipient with its subject and body', async () => {
      const { sendEmail } = await harness.load();

      await expect(sendEmail(plainEmail)).resolves.toBeUndefined();

      expect(await harness.delivered()).toEqual([
        expect.objectContaining({ to: plainEmail.to, subject: plainEmail.subject, body }),
      ]);
    });

    it('delivers a formatted email with its React body rendered', async () => {
      const { sendFormattedEmail } = await harness.load();

      await expect(sendFormattedEmail(formattedEmail)).resolves.toBeUndefined();

      expect(await harness.delivered()).toEqual([
        expect.objectContaining({ to: formattedEmail.to, subject: formattedEmail.subject, body }),
      ]);
    });

    it('sends from the configured default sender unless the email sets one', async () => {
      const { sendEmail } = await harness.load();

      await sendEmail(plainEmail);
      await sendEmail({ ...plainEmail, from: 'other@example.com' });

      const senders = (await harness.delivered()).map(({ from }) => from);
      expect(senders).toEqual([harness.defaultFrom, 'other@example.com']);
    });

    it('rejects both email types when the vendor reports a failure', async () => {
      harness.failDelivery('vendor rejected the message');
      const { sendEmail, sendFormattedEmail } = await harness.load();

      const message: unknown = expect.stringContaining('vendor rejected the message');
      const failure = { message };
      await expect(sendEmail(plainEmail)).rejects.toMatchObject(failure);
      await expect(sendFormattedEmail(formattedEmail)).rejects.toMatchObject(failure);
    });

    describe.each(harness.requiredConfig)('without $name', ({ remove }) => {
      it('refuses to send instead of dropping the email', async () => {
        remove();
        const send = async () => (await harness.load()).sendEmail(plainEmail);

        await expect(send()).rejects.toBeInstanceOf(Error);
        expect(await harness.delivered()).toEqual([]);
      });
    });
  });
}
