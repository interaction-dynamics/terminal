import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { NotificationProvider } from './interfaces';

/** A notification as the vendor received it, translated back into port terms. */
export interface DeliveredNotification {
  /** Every piece of text the recipient sees, title included. */
  text: string;
  channel?: string;
}

export interface NotificationContractHarness {
  /** Sets the env vars and vendor mock defaults that let the vendor deliver. Runs before each test. */
  configure: () => void;
  /** Imports a fresh copy of the adapter so it reads the current configuration. */
  load: () => Promise<NotificationProvider>;
  /** Notifications the mocked vendor received. */
  delivered: () => DeliveredNotification[];
  /** Makes the mocked vendor refuse the notification, as it does for a revoked webhook. */
  failDelivery: () => void;
  /** Config without which the adapter must refuse to send (ADR 0021), and how to remove it. */
  requiredConfig: { name: string; remove: () => void }[];
}

/**
 * Behaviour every `NotificationProvider` vendor must share so feature code can swap them.
 * Call it from `<vendor>/<vendor>.contract.test.ts` with the vendor transport mocked.
 */
export function describeNotificationContract(
  vendor: string,
  harness: NotificationContractHarness,
): void {
  describe(`${vendor} notification adapter contract`, () => {
    beforeEach(() => {
      vi.resetModules();
      harness.configure();
    });

    afterEach(() => {
      vi.unstubAllEnvs();
      vi.unstubAllGlobals();
      vi.resetAllMocks();
    });

    it('delivers the message', async () => {
      const { sendNotification } = await harness.load();

      await expect(sendNotification({ message: 'Deploy finished' })).resolves.toBeUndefined();

      expect(harness.delivered()).toEqual([expect.objectContaining({ text: 'Deploy finished' })]);
    });

    it('delivers the title alongside the message', async () => {
      const { sendNotification } = await harness.load();

      await sendNotification({ title: 'Release', message: 'Deploy finished' });

      const titleThenMessage: unknown = expect.stringMatching(/Release[\s\S]*Deploy finished/);
      expect(harness.delivered()).toEqual([expect.objectContaining({ text: titleThenMessage })]);
    });

    it('routes to the requested channel', async () => {
      const { sendNotification } = await harness.load();

      await sendNotification({ message: 'Deploy finished', channel: '#releases' });

      expect(harness.delivered()).toEqual([expect.objectContaining({ channel: '#releases' })]);
    });

    it('rejects when the vendor refuses the notification', async () => {
      harness.failDelivery();
      const { sendNotification } = await harness.load();

      await expect(sendNotification({ message: 'Deploy finished' })).rejects.toBeInstanceOf(Error);
    });

    describe.each(harness.requiredConfig)('without $name', ({ remove }) => {
      it('refuses to send instead of dropping the notification', async () => {
        remove();
        const send = async () => (await harness.load()).sendNotification({ message: 'Hi' });

        await expect(send()).rejects.toBeInstanceOf(Error);
        expect(harness.delivered()).toEqual([]);
      });
    });
  });
}
