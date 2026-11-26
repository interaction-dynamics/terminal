import type { ReactElement } from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { LoginFormComponentProps } from '../config';

const createVerificationOTP = vi.hoisted(() => vi.fn<() => Promise<string>>());
const sendOtpEmail = vi.hoisted(() => vi.fn<(email: object) => Promise<void>>());
const signInEmailOTP = vi.hoisted(() => vi.fn<() => Promise<void>>());

vi.mock('./auth', () => ({ auth: { api: { createVerificationOTP, signInEmailOTP } } }));
vi.mock('./send-otp-email', () => ({ sendOtpEmail }));
vi.mock('next/headers', () => ({ headers: async () => new Headers() }));

import { APIError } from 'better-auth/api';
import { createBetterAuthAdapter } from './index';

const LoginFormComponent = () => null;

const onSend = (email: string) => {
  const { LoginForm } = createBetterAuthAdapter({ protectedRoutes: [], LoginFormComponent });
  const form = LoginForm({}) as ReactElement<LoginFormComponentProps>;
  return form.props.onSend(email);
};

const onVerify = (email: string, code: string) => {
  const { LoginForm } = createBetterAuthAdapter({ protectedRoutes: [], LoginFormComponent });
  const form = LoginForm({}) as ReactElement<LoginFormComponentProps>;
  return form.props.onVerify?.(email, code);
};

describe('Better Auth LoginForm onVerify', () => {
  afterEach(() => {
    vi.resetAllMocks();
  });

  it('tells a blocked user their account is blocked rather than that the code is wrong', async () => {
    signInEmailOTP.mockRejectedValue(
      APIError.from('FORBIDDEN', { code: 'BANNED_USER', message: 'Blocked' }),
    );

    await expect(onVerify('blocked@example.com', '123456')).resolves.toEqual({
      error: 'This account has been blocked',
    });
  });

  it('reports any other failure as an invalid code', async () => {
    signInEmailOTP.mockRejectedValue(new Error('INVALID_OTP'));

    await expect(onVerify('user@example.com', '000000')).resolves.toEqual({
      error: 'Invalid verification code',
    });
  });
});

describe('Better Auth LoginForm onSend', () => {
  afterEach(() => {
    vi.resetAllMocks();
    vi.restoreAllMocks();
  });

  it('emails the created code', async () => {
    createVerificationOTP.mockResolvedValue('123456');
    sendOtpEmail.mockResolvedValue();

    await expect(onSend('user@example.com')).resolves.toEqual({});
    expect(sendOtpEmail).toHaveBeenCalledWith({
      email: 'user@example.com',
      otp: '123456',
      type: 'sign-in',
    });
  });

  it('reports and logs a failure when the email cannot be sent', async () => {
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});
    const cause = new Error('No email provider is configured');
    createVerificationOTP.mockResolvedValue('123456');
    sendOtpEmail.mockRejectedValue(cause);

    await expect(onSend('user@example.com')).resolves.toEqual({
      error: 'Failed to send verification code',
    });
    expect(consoleError).toHaveBeenCalledWith('Failed to send verification code:', cause);
  });
});
