import { isEmailConfigured, sendFormattedEmail } from '@ship-it/adapters/email';
import { OTPEmail } from './emails/otp-email';

const subjects: Record<Parameters<typeof OTPEmail>[0]['type'], string> = {
  'sign-in': 'Your sign-in code',
  'forget-password': 'Your password reset code',
  'email-verification': 'Your verification code',
  'change-email': 'Your verification code',
};

export async function sendOtpEmail({
  email,
  otp,
  type,
}: Parameters<typeof OTPEmail>[0] & { email: string }): Promise<void> {
  if (!isEmailConfigured()) {
    throw new Error(
      'No email provider is configured, so verification codes cannot be delivered. Set RESEND_API_KEY or MAILGUN_API_KEY.',
    );
  }

  await sendFormattedEmail({
    to: [email],
    subject: `${subjects[type]}: ${otp}`,
    react: OTPEmail({ otp, type }),
  });
}
