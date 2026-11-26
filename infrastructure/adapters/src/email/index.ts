import type { EmailProvider } from './interfaces';
import { emailEnv } from './env';

export type {
  IEmail,
  Email,
  FormattedEmail,
  SendEmail,
  SendFormattedEmail,
  EmailProvider,
} from './interfaces';

// Pick exactly one provider rather than merging them, so the compiler requires each vendor to
// implement the whole port and no method can silently resolve to the blank no-op.
export const getProvider = async (): Promise<EmailProvider> => {
  const { RESEND_API_KEY, MAILGUN_API_KEY } = emailEnv();
  if (RESEND_API_KEY) return import('./resend');
  if (MAILGUN_API_KEY) return import('./mailgun');
  return import('./blank');
};

/**
 * False when emails are dropped by the blank provider. Flows that cannot work without the email
 * reaching the user, such as sign-in codes, should check this and fail.
 */
export const isEmailConfigured = (): boolean => {
  const { RESEND_API_KEY, MAILGUN_API_KEY } = emailEnv();
  return Boolean(RESEND_API_KEY || MAILGUN_API_KEY);
};

const provider = await getProvider();

export const { sendEmail, sendFormattedEmail } = provider;
