import { afterEach, describe, expect, it, vi } from 'vitest';
import type { FormattedEmail } from '../../email/interfaces';

const sendFormattedEmail = vi.hoisted(() => vi.fn<(email: FormattedEmail) => Promise<void>>());
const isEmailConfigured = vi.hoisted(() => vi.fn<() => boolean>());

vi.mock('@ship-it/adapters/email', () => ({ sendFormattedEmail, isEmailConfigured }));

import { sendOtpEmail } from './send-otp-email';

const otpEmail = { email: 'user@example.com', otp: '123456', type: 'sign-in' } as const;

describe('sendOtpEmail', () => {
  afterEach(() => {
    vi.resetAllMocks();
  });

  it('rejects instead of dropping the code when no email vendor is configured', async () => {
    isEmailConfigured.mockReturnValue(false);

    await expect(sendOtpEmail(otpEmail)).rejects.toThrow('No email provider is configured');
    expect(sendFormattedEmail).not.toHaveBeenCalled();
  });

  it('sends the code when an email vendor is configured', async () => {
    isEmailConfigured.mockReturnValue(true);

    await sendOtpEmail(otpEmail);

    expect(sendFormattedEmail).toHaveBeenCalledWith(
      expect.objectContaining({ to: ['user@example.com'], subject: 'Your sign-in code: 123456' }),
    );
  });

  it('rejects when the vendor fails', async () => {
    isEmailConfigured.mockReturnValue(true);
    sendFormattedEmail.mockRejectedValue(new Error('unauthorized'));

    await expect(sendOtpEmail(otpEmail)).rejects.toThrow('unauthorized');
  });
});
