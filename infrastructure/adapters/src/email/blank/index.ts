import type { Email, FormattedEmail } from '../interfaces';

export function sendEmail(_email: Email): Promise<void> {
  return Promise.resolve();
}

export function sendFormattedEmail(_email: FormattedEmail): Promise<void> {
  return Promise.resolve();
}
