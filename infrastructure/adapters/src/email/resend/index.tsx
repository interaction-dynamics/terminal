import { Resend } from 'resend';
import type { Email, FormattedEmail, IEmail } from '../interfaces';
import { emailEnv } from '../env';

const resend = new Resend(emailEnv().RESEND_API_KEY);

const fromAddress = (email: IEmail) => email.from ?? emailEnv().RESEND_EMAIL_FROM ?? '';

export async function sendEmail(email: Email): Promise<void> {
  const { error } = await resend.emails.send({
    from: fromAddress(email),
    to: email.to,
    subject: email.subject,
    text: email.text,
    html: email.html,
  });

  if (error) {
    // Resend reports failures as a plain `{ name, message }` object; wrap it so callers get a
    // real Error with a stack trace and can still inspect the original response via `cause`.
    throw new Error(error.message, { cause: error });
  }
}

export async function sendFormattedEmail(email: FormattedEmail): Promise<void> {
  const { error } = await resend.emails.send({
    from: fromAddress(email),
    to: email.to,
    subject: email.subject,
    react: email.react,
  });

  if (error) {
    // Resend reports failures as a plain `{ name, message }` object; wrap it so callers get a
    // real Error with a stack trace and can still inspect the original response via `cause`.
    throw new Error(error.message, { cause: error });
  }
}
